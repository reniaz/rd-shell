#!/usr/bin/env bash
# One JSON line describing the machine: CPU jiffies, memory, temperatures and
# the two GPUs. Cumulative counters are printed raw -- the caller keeps the
# previous sample and turns the difference into a percentage, which is both
# cheaper and more accurate than sleeping here for a second reading.
set -u

export DISPLAY="${DISPLAY:-:0}"

# --- cpu: one [total, idle] pair per line of /proc/stat ---------------------
cpu=$(awk '
    /^cpu[0-9]*  ?/ {
        total = 0
        for (i = 2; i <= 9; i++) total += $i
        idle = $5 + $6
        printf "%s[%d,%d]", (n++ ? "," : ""), total, idle
    }
' /proc/stat)

# Cores idle at a few hundred MHz and boost past 5GHz; the average across them
# is what the load figure beside it is actually running at.
mhz=$(awk '{ sum += $1; n++ } END { printf "%.0f", n ? sum / n / 1000 : 0 }' \
    /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq 2>/dev/null)
[ -n "$mhz" ] || mhz=0

# --- memory ----------------------------------------------------------------
mem=$(awk '
    /^MemTotal:/     { t = $2 }
    /^MemAvailable:/ { a = $2 }
    /^Cached:/       { c = $2 }
    /^Buffers:/      { b = $2 }
    /^SwapTotal:/    { st = $2 }
    /^SwapFree:/     { sf = $2 }
    END { printf "\"memTotal\":%d,\"memAvail\":%d,\"cached\":%d,\"swapTotal\":%d,\"swapUsed\":%d",
          t * 1024, a * 1024, (c + b) * 1024, st * 1024, (st - sf) * 1024 }
' /proc/meminfo)

# --- hwmon: whichever chip carries the package temperature -----------------
read_temp() {
    local file=$1
    [ -r "$file" ] || return 1
    awk '{ printf "%.1f", $1 / 1000 }' "$file"
}

cpu_temp=null
gpu_busy=null
igpu_temp=null
igpu_power=null

for chip in /sys/class/hwmon/hwmon*; do
    case "$(cat "$chip/name" 2>/dev/null)" in
        # Tctl on AMD, Package id 0 on Intel: both land on temp1_input.
        k10temp|coretemp|zenpower)
            cpu_temp=$(read_temp "$chip/temp1_input") || cpu_temp=null ;;
        amdgpu)
            igpu_temp=$(read_temp "$chip/temp1_input") || igpu_temp=null
            [ -r "$chip/power1_input" ] &&
                igpu_power=$(awk '{ printf "%.1f", $1 / 1000000 }' "$chip/power1_input")
            [ -r "$chip/device/gpu_busy_percent" ] &&
                gpu_busy=$(cat "$chip/device/gpu_busy_percent") ;;
    esac
done

# --- nvidia ----------------------------------------------------------------
# Queried through nvidia-settings rather than nvidia-smi, which this driver
# install does not ship. It answers over the X connection in ~60ms; utilisation
# is not among the attributes it exposes, so only temperature and VRAM are read.
nv_temp=null
nv_used=null
nv_total=null
nv_fan=null

if [ -d /proc/driver/nvidia/gpus ]; then
    nv=$(timeout 3 nvidia-settings -t \
        -q GPUCoreTemp -q UsedDedicatedGPUMemory -q TotalDedicatedGPUMemory \
        -q GPUCurrentFanSpeedRPM \
        2>/dev/null | tr '\n' ' ')
    # Three fixed answers and then one line per fan, so the fans are whatever
    # is left over rather than a fourth field.
    set -- $nv
    if [ $# -ge 3 ]; then
        nv_temp=$1
        nv_used=$(( $2 * 1048576 ))
        nv_total=$(( $3 * 1048576 ))
        shift 3
        nv_fan=0
        for rpm in "$@"; do
            [ "$rpm" -gt "$nv_fan" ] 2>/dev/null && nv_fan=$rpm
        done
    fi
fi

read -r uptime _ < /proc/uptime
read -r l1 l5 l15 procs _ < /proc/loadavg

printf '{"cpu":[%s],"cpuTemp":%s,"cpuMhz":%s,%s,"uptime":%.0f,"load":[%s,%s,%s],"procs":"%s",' \
    "$cpu" "$cpu_temp" "$mhz" "$mem" "$uptime" "$l1" "$l5" "$l15" "$procs"
printf '"gpuTemp":%s,"gpuMemUsed":%s,"gpuMemTotal":%s,"gpuFan":%s,' \
    "$nv_temp" "$nv_used" "$nv_total" "$nv_fan"
printf '"igpuTemp":%s,"igpuBusy":%s,"igpuPower":%s}\n' "$igpu_temp" "$gpu_busy" "$igpu_power"
