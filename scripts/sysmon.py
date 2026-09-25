#!/usr/bin/env python3
# One long-running sampler replacing sysmon.sh + sysmon-procs.sh + nvidia-settings.
#
# stdout: one JSON object per line, flushed immediately. First line ~0.5s
# after start (CPU % needs two /proc/stat reads, taken here rather than left
# for the caller -- a script that blocks on Popen would need the same wait
# either way, and doing it once, here, means the JSON already carries a
# percentage instead of raw counters for SysMon.qml to diff).
#
# stdin, one command per line:
#   procs on   -- start scanning /proc/[pid] each tick (the popup is open)
#   procs off  -- stop (the popup is closed; scanning ~1500 processes has a
#                 real CPU cost that is only worth paying while shown)
#   scan       -- emit one extra sample right now, processes included if on
#                 (used right after a kill, so the list drops the dead pid
#                 without waiting out the rest of the 2s tick)
#
# Reasoning for anything non-obvious lives next to the code it explains,
# not up here, so it stays next to what changes.
import ctypes
import glob
import json
import os
import pwd
import re
import sys
import time

HZ = os.sysconf("SC_CLK_TCK")
PAGESIZE = os.sysconf("SC_PAGE_SIZE")
SELF_PID = os.getpid()
TICK = 2.0

# Interpreters/shells: the process actually doing the work is named by its
# comm (the script), not by "python3.14" or "bash", which every unrelated
# script would also collapse into.
INTERP_RE = re.compile(r"^(python[0-9.]*|sh|bash|zsh|fish|node|perl|ruby|lua[0-9.]*)$")


# ── /proc/stat, /proc/meminfo, /proc/loadavg, cpufreq ───────────────────────

def read_cpu_stat():
    """[ (total, idle_and_iowait, iowait) ... ] -- index 0 is the aggregate
    'cpu' line, the rest are cpu0, cpu1, ... in order. idle is merged with
    iowait here (see _cpu_percents) so cpuPercent keeps the exact meaning the
    old bash script gave it; iowait is also kept on its own for the new
    field."""
    rows = []
    with open("/proc/stat") as f:
        for line in f:
            if not line.startswith("cpu"):
                if rows:
                    break
                continue
            parts = line.split()
            vals = list(map(int, parts[1:9])) if len(parts) >= 9 else \
                list(map(int, parts[1:])) + [0] * (8 - (len(parts) - 1))
            user, nice, system, idle, iowait, irq, softirq, steal = vals[:8]
            total = user + nice + system + idle + iowait + irq + softirq + steal
            rows.append((total, idle + iowait, iowait))
    return rows


def cpu_percents(prev, cur):
    """(aggregate_pct, [core_pct...], iowait_pct) from two read_cpu_stat()
    samples. A counter that did not move at all means an offline core, not a
    fully loaded one -- 0%, not 100%."""
    pct = []
    for (t0, i0, _), (t1, i1, _) in zip(prev, cur):
        dt, di = t1 - t0, i1 - i0
        pct.append(max(0, min(100, round((1 - di / dt) * 100))) if dt > 0 else 0)
    dt0 = cur[0][0] - prev[0][0]
    dio = cur[0][2] - prev[0][2]
    iowait_pct = round(dio / dt0 * 100, 1) if dt0 > 0 else 0.0
    return pct[0], pct[1:], iowait_pct


def read_core_mhz():
    freqs = []
    for p in sorted(glob.glob("/sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq"),
                     key=lambda p: int(re.search(r"cpu(\d+)", p).group(1))):
        try:
            with open(p) as f:
                freqs.append(round(int(f.read()) / 1000))
        except OSError:
            pass
    return freqs


def read_meminfo():
    v = {}
    try:
        with open("/proc/meminfo") as f:
            for line in f:
                k, rest = line.split(":", 1)
                v[k] = int(rest.split()[0]) * 1024
    except OSError:
        pass
    return v


def read_zram():
    orig = compr = 0
    for p in glob.glob("/sys/block/zram*/mm_stat"):
        try:
            with open(p) as f:
                parts = f.read().split()
            orig += int(parts[0])
            compr += int(parts[1])
        except (OSError, IndexError, ValueError):
            pass
    ratio = round(orig / compr, 2) if compr > 0 else 0
    return orig, compr, ratio


def read_loadavg():
    try:
        with open("/proc/loadavg") as f:
            l1, l5, l15, procs, _ = f.read().split()
        running, total = procs.split("/")
        return [float(l1), float(l5), float(l15)], int(running), procs
    except (OSError, ValueError):
        return [0.0, 0.0, 0.0], 0, ""


def read_uptime():
    try:
        with open("/proc/uptime") as f:
            return float(f.read().split()[0])
    except OSError:
        return 0.0


def read_cpu_model():
    try:
        with open("/proc/cpuinfo") as f:
            for line in f:
                if line.startswith("model name"):
                    name = line.split(":", 1)[1].strip()
                    # "N-Core Processor" is marketing filler once the core
                    # count is already on screen elsewhere in the popup.
                    return re.sub(r"\s*\d+-Core Processor\s*", "", name)
    except OSError:
        pass
    return ""


# ── hwmon, discovered once by chip name ──────────────────────────────────────

def _hwmon_chips():
    chips = {}
    for path in glob.glob("/sys/class/hwmon/hwmon*"):
        try:
            with open(f"{path}/name") as f:
                chips.setdefault(f.read().strip(), path)
        except OSError:
            pass
    return chips


def _label_input(chip_path, label):
    for lf in glob.glob(f"{chip_path}/temp*_label"):
        try:
            with open(lf) as f:
                if f.read().strip() == label:
                    return lf[:-len("_label")] + "_input"
        except OSError:
            pass
    return None


def _read_milli(path, scale=1000.0):
    try:
        with open(path) as f:
            return round(int(f.read()) / scale, 1)
    except (OSError, ValueError):
        return None


class Hwmon:
    """Every sysfs path this sampler ever reads, resolved once at start so
    every later tick is a handful of plain file reads and no globbing."""

    def __init__(self):
        chips = _hwmon_chips()

        self.cpu_temp_file = None
        for name in ("k10temp", "zenpower"):
            if name in chips:
                self.cpu_temp_file = _label_input(chips[name], "Tctl") or f"{chips[name]}/temp1_input"
                break
        if self.cpu_temp_file is None and "coretemp" in chips:
            self.cpu_temp_file = _label_input(chips["coretemp"], "Package id 0") or f"{chips['coretemp']}/temp1_input"

        amdgpu = chips.get("amdgpu")
        self.igpu_temp_file = f"{amdgpu}/temp1_input" if amdgpu else None
        self.igpu_power_file = f"{amdgpu}/power1_input" if amdgpu else None
        self.igpu_busy_file = f"{amdgpu}/device/gpu_busy_percent" if amdgpu else None

    def sample(self):
        cpu_temp = _read_milli(self.cpu_temp_file) if self.cpu_temp_file else None
        igpu_temp = _read_milli(self.igpu_temp_file) if self.igpu_temp_file else None
        igpu_power = _read_milli(self.igpu_power_file, 1_000_000.0) if self.igpu_power_file else None
        igpu_busy = None
        if self.igpu_busy_file:
            try:
                with open(self.igpu_busy_file) as f:
                    igpu_busy = int(f.read())
            except (OSError, ValueError):
                pass
        return {
            "cpuTemp": cpu_temp if cpu_temp is not None else -1,
            "igpuTemp": igpu_temp if igpu_temp is not None else -1,
            "igpuPower": igpu_power if igpu_power is not None else -1,
            "igpuBusy": igpu_busy if igpu_busy is not None else -1,
        }


# ── NVIDIA, via NVML directly (no nvidia-smi on this driver install) ────────

class _Util(ctypes.Structure):
    _fields_ = [("gpu", ctypes.c_uint), ("memory", ctypes.c_uint)]


class _Mem(ctypes.Structure):
    _fields_ = [("total", ctypes.c_ulonglong), ("free", ctypes.c_ulonglong), ("used", ctypes.c_ulonglong)]


class _ProcInfo(ctypes.Structure):
    _fields_ = [("pid", ctypes.c_uint), ("usedGpuMemory", ctypes.c_ulonglong),
                ("gpuInstanceId", ctypes.c_uint), ("computeInstanceId", ctypes.c_uint)]


class _FanSpeedInfo(ctypes.Structure):
    _fields_ = [("version", ctypes.c_uint), ("fan", ctypes.c_uint), ("speed", ctypes.c_uint)]


UNKNOWN_VRAM = 1 << 60  # NVML's "not available" sentinel for usedGpuMemory


class Nvml:
    """Best-effort NVML wrapper. Any failure anywhere -- library missing, no
    card, a call that errors -- leaves `ok` False (or that one field absent)
    and never raises out of `sample()`/`processes()`; a machine with no NVIDIA
    card is the normal case on plenty of installs, not a fault."""

    def __init__(self):
        self.ok = False
        self.name = ""
        self.driver = ""
        self._has_fan_rpm = False
        try:
            self.lib = ctypes.CDLL("libnvidia-ml.so.1")
            if self.lib.nvmlInit_v2() != 0:
                return
            cnt = ctypes.c_uint()
            if self.lib.nvmlDeviceGetCount_v2(ctypes.byref(cnt)) != 0 or cnt.value < 1:
                return
            self.h = ctypes.c_void_p()
            if self.lib.nvmlDeviceGetHandleByIndex_v2(0, ctypes.byref(self.h)) != 0:
                return
            self.ok = True
            self._has_fan_rpm = hasattr(self.lib, "nvmlDeviceGetFanSpeedRPM")
        except OSError:
            return

        buf = ctypes.create_string_buffer(96)
        if self.lib.nvmlDeviceGetName(self.h, buf, 96) == 0:
            self.name = buf.value.decode(errors="ignore").replace("NVIDIA ", "")
        drv = ctypes.create_string_buffer(80)
        if self.lib.nvmlSystemGetDriverVersion(drv, 80) == 0:
            self.driver = drv.value.decode(errors="ignore")

    def _u(self, fn):
        v = ctypes.c_uint()
        return v.value if fn(ctypes.byref(v)) == 0 else -1

    def sample(self):
        if not self.ok:
            return {}
        d = {"gpuName": self.name, "gpuDriver": self.driver}

        try:
            u = _Util()
            if self.lib.nvmlDeviceGetUtilizationRates(self.h, ctypes.byref(u)) == 0:
                d["gpuUtil"], d["gpuMemUtil"] = u.gpu, u.memory
        except Exception:
            pass

        try:
            m = _Mem()
            if self.lib.nvmlDeviceGetMemoryInfo(self.h, ctypes.byref(m)) == 0:
                d["gpuMemUsed"], d["gpuMemTotal"] = m.used, m.total
        except Exception:
            pass

        try:
            d["gpuTemp"] = self._u(lambda p: self.lib.nvmlDeviceGetTemperature(self.h, 0, p))
        except Exception:
            d["gpuTemp"] = -1

        try:
            p = self._u(lambda p: self.lib.nvmlDeviceGetPowerUsage(self.h, p))
            d["gpuPower"] = round(p / 1000, 1) if p >= 0 else -1
        except Exception:
            d["gpuPower"] = -1

        try:
            pl = self._u(lambda p: self.lib.nvmlDeviceGetEnforcedPowerLimit(self.h, p))
            d["gpuPowerLimit"] = round(pl / 1000, 1) if pl >= 0 else -1
        except Exception:
            d["gpuPowerLimit"] = -1

        try:
            d["gpuClock"] = self._u(lambda p: self.lib.nvmlDeviceGetClockInfo(self.h, 0, p))
        except Exception:
            d["gpuClock"] = -1
        try:
            d["gpuMemClock"] = self._u(lambda p: self.lib.nvmlDeviceGetClockInfo(self.h, 2, p))
        except Exception:
            d["gpuMemClock"] = -1

        try:
            d["gpuFanPercent"] = self._u(lambda p: self.lib.nvmlDeviceGetFanSpeed(self.h, p))
        except Exception:
            d["gpuFanPercent"] = -1

        d["gpuFan"] = -1
        if self._has_fan_rpm:
            try:
                info = _FanSpeedInfo()
                info.version = ctypes.sizeof(_FanSpeedInfo) | (1 << 24)
                info.fan = 0
                if self.lib.nvmlDeviceGetFanSpeedRPM(self.h, ctypes.byref(info)) == 0:
                    d["gpuFan"] = info.speed
            except Exception:
                pass

        try:
            d["gpuPstate"] = self._u(lambda p: self.lib.nvmlDeviceGetPerformanceState(self.h, p))
        except Exception:
            d["gpuPstate"] = -1

        try:
            eu, esp = ctypes.c_uint(), ctypes.c_uint()
            if self.lib.nvmlDeviceGetEncoderUtilization(self.h, ctypes.byref(eu), ctypes.byref(esp)) == 0:
                d["gpuEnc"] = eu.value
        except Exception:
            pass
        try:
            du, dsp = ctypes.c_uint(), ctypes.c_uint()
            if self.lib.nvmlDeviceGetDecoderUtilization(self.h, ctypes.byref(du), ctypes.byref(dsp)) == 0:
                d["gpuDec"] = du.value
        except Exception:
            pass

        return d

    def process_vram(self):
        """pid -> VRAM bytes, from both the graphics and compute running-process
        lists. Two-call pattern: NVML reports the required count on a first
        call with no buffer, so the array is allocated exactly once."""
        if not self.ok:
            return {}
        out = {}
        for fname in ("nvmlDeviceGetGraphicsRunningProcesses_v3", "nvmlDeviceGetComputeRunningProcesses_v3"):
            fn = getattr(self.lib, fname, None)
            if fn is None:
                continue
            try:
                n = ctypes.c_uint(0)
                fn(self.h, ctypes.byref(n), None)  # NVML_ERROR_INSUFFICIENT_SIZE fills n
                if n.value == 0:
                    continue
                arr = (_ProcInfo * n.value)()
                if fn(self.h, ctypes.byref(n), arr) != 0:
                    continue
                for i in range(n.value):
                    mem = arr[i].usedGpuMemory
                    if mem < UNKNOWN_VRAM:
                        out[arr[i].pid] = out.get(arr[i].pid, 0) + mem
            except Exception:
                continue
        return out


# ── per-process grouping (only while `procs on`) ─────────────────────────────

def _proc_extra(pid):
    """cmdline + owning user, read only for the handful of groups actually
    emitted -- never for all ~1500 processes on the box."""
    try:
        user = pwd.getpwuid(os.stat(f"/proc/{pid}").st_uid).pw_name
    except (OSError, KeyError):
        user = ""
    try:
        with open(f"/proc/{pid}/cmdline", "rb") as f:
            raw = f.read()
        cmdline = raw.replace(b"\x00", b" ").decode(errors="replace").strip()
    except OSError:
        cmdline = ""
    return user, cmdline


def scan_processes(nthreads, elapsed, prev_ticks, uptime, vram_map):
    """One pass over /proc/[pid]/stat: builds app-level groups and the ticks
    map the next tick's cpu delta needs. rss comes straight out of stat (no
    /proc/[pid]/status read needed); cmdline/user are deferred to the caller,
    for only the groups that make the cut."""
    groups = {}
    new_ticks = {}

    for entry in os.listdir("/proc"):
        if not entry.isdigit():
            continue
        pid = int(entry)
        # Init is never a row: grouped by exe it lands in the same "systemd"
        # group as the user manager, and End on that row would signal pid 1.
        if pid == SELF_PID or pid == 1:
            continue

        try:
            with open(f"/proc/{entry}/stat", "rb") as f:
                raw = f.read().decode(errors="replace")
        except OSError:
            continue

        rparen = raw.rfind(")")
        lparen = raw.find("(")
        if rparen < 0 or lparen < 0:
            continue
        comm = raw[lparen + 1:rparen]
        rest = raw[rparen + 2:].split()
        try:
            state = rest[0]
            ppid = int(rest[1])
            utime = int(rest[11])
            stime = int(rest[12])
            num_threads = int(rest[17])
            starttime = int(rest[19])
            rss = int(rest[21]) * PAGESIZE
        except (IndexError, ValueError):
            continue

        ticks = utime + stime
        new_ticks[pid] = ticks

        try:
            exe = os.path.basename(os.readlink(f"/proc/{entry}/exe"))
        except OSError:
            exe = None

        # Kernel threads: no /proc/pid/exe, parented by kthreadd (or kthreadd
        # itself) -- never a real workload to show in an app list.
        if exe is None and (ppid == 2 or pid == 2):
            continue

        key = comm if (exe is None or INTERP_RE.match(exe)) else exe

        prev = prev_ticks.get(pid)
        cpu_pct = max(0.0, (ticks - prev) / (elapsed * HZ * nthreads) * 100) \
            if prev is not None and elapsed > 0 else 0.0

        g = groups.get(key)
        if g is None:
            g = groups[key] = {"key": key, "cpu": 0.0, "mem": 0, "vram": 0,
                                "pids": [], "heavy_pid": pid, "heavy_cpu": -1.0}
        g["pids"].append(pid)
        g["cpu"] += cpu_pct
        g["mem"] += rss
        g["vram"] += vram_map.get(pid, 0)
        if cpu_pct > g["heavy_cpu"]:
            g["heavy_cpu"] = cpu_pct
            g["heavy_pid"] = pid
            g["_state"] = state
            g["_threads"] = num_threads
            g["_runtime"] = max(0.0, uptime - starttime / HZ)

    by_cpu = sorted(groups.values(), key=lambda g: g["cpu"], reverse=True)[:15]
    by_mem = sorted(groups.values(), key=lambda g: g["mem"], reverse=True)[:15]
    chosen = {g["key"]: g for g in by_cpu}
    chosen.update({g["key"]: g for g in by_mem})
    chosen.update({g["key"]: g for g in groups.values() if g["vram"] > 0})

    out = []
    for g in chosen.values():
        user, cmdline = _proc_extra(g["heavy_pid"])
        out.append({
            "key": g["key"], "name": g["key"], "pid": g["heavy_pid"],
            "pids": g["pids"], "count": len(g["pids"]),
            "cpu": round(g["cpu"], 1), "mem": g["mem"], "vram": g["vram"],
            "user": user, "cmdline": cmdline or f"[{g['key']}]",
            "threads": g["_threads"], "runtime": round(g["_runtime"]),
            "state": g["_state"],
        })
    return out, new_ticks


# ── main loop ─────────────────────────────────────────────────────────────────

def main():
    nthreads = os.cpu_count() or 1
    hwmon = Hwmon()
    nvml = Nvml()
    cpu_model = read_cpu_model()

    prev_cpu = read_cpu_stat()
    time.sleep(0.5)  # two /proc/stat reads are needed before any % means anything

    procs_on = False
    prev_ticks = {}
    prev_scan_time = None

    def emit():
        nonlocal prev_cpu, prev_ticks, prev_scan_time

        cur_cpu = read_cpu_stat()
        agg, cores, iowait = cpu_percents(prev_cpu, cur_cpu)
        prev_cpu = cur_cpu

        mem = read_meminfo()
        zram_orig, zram_compr, zram_ratio = read_zram()
        load, running, procs_str = read_loadavg()
        uptime = read_uptime()

        d = {
            "cpuPercent": agg, "cores": cores, "iowait": iowait,
            "coreMhz": read_core_mhz(),
            "cpuModel": cpu_model,
            "cpuTemp": -1,
            "running": running, "procs": procs_str,
            "memTotal": mem.get("MemTotal", 0), "memAvail": mem.get("MemAvailable", 0),
            "memFree": mem.get("MemFree", 0),
            "cached": mem.get("Cached", 0) + mem.get("Buffers", 0),
            "swapTotal": mem.get("SwapTotal", 0),
            "swapUsed": mem.get("SwapTotal", 0) - mem.get("SwapFree", 0),
            "zramOrig": zram_orig, "zramCompr": zram_compr, "zramRatio": zram_ratio,
            "uptime": uptime, "load": load,
        }
        # cpuMhz: mean of the same per-thread reading `coreMhz` just took --
        # computed from that array rather than a second glob of the same files.
        d["cpuMhz"] = round(sum(d["coreMhz"]) / len(d["coreMhz"])) if d["coreMhz"] else 0

        d.update(hwmon.sample())
        d.update(nvml.sample())

        if procs_on:
            now = time.monotonic()
            elapsed = (now - prev_scan_time) if prev_scan_time else 0.0
            vram_map = nvml.process_vram()
            processes, prev_ticks = scan_processes(nthreads, elapsed, prev_ticks, uptime, vram_map)
            prev_scan_time = now
            d["processes"] = processes
        else:
            # Dropped, not carried stale, once the popup closes -- the UI
            # stops reading it anyway once panelOpen goes false.
            prev_ticks = {}
            prev_scan_time = None

        sys.stdout.write(json.dumps(d) + "\n")
        sys.stdout.flush()

    emit()  # first line, ~0.5s in

    next_tick = time.monotonic() + TICK
    while True:
        timeout = max(0.0, next_tick - time.monotonic())
        line = _readline_with_timeout(timeout)
        if line is _EOF:
            return
        if line is not None:
            cmd = line.strip()
            if cmd == "procs on":
                procs_on = True
            elif cmd == "procs off":
                procs_on = False
            elif cmd == "scan":
                emit()
            continue
        emit()
        next_tick = time.monotonic() + TICK


_EOF = object()


def _readline_with_timeout(timeout):
    """None on plain timeout, a stripped-nothing line is still a line, _EOF
    once the parent has closed our stdin (SysMon.qml Process died/stopped)."""
    import select
    ready, _, _ = select.select([sys.stdin], [], [], timeout)
    if not ready:
        return None
    line = sys.stdin.readline()
    if line == "":
        return _EOF
    return line


if __name__ == "__main__":
    try:
        main()
    except (BrokenPipeError, KeyboardInterrupt):
        pass
