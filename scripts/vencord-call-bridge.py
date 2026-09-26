#!/usr/bin/env python3
# Minimal RFC 6455 WebSocket server for the Vencord "XSOverlay" plugin.
#
# Why this exists: Vesktop sends no desktop notification for an incoming
# call (a real call produced none), so Services/DiscordCall.qml cannot watch
# org.freedesktop.Notifications for one. What Vesktop's own Vencord *can* do
# instead is speak the XSOverlay plugin's tiny protocol: on CALL_UPDATE, from
# the discord.com page itself, it opens `ws://127.0.0.1:42070/?client=Vencord`
# and sends one text frame shaped like:
#   {"sender":"Vencord","target":"xsoverlay","command":"SendNotification",
#    "jsonData":"<json string>","rawData":null}
# where jsonData (itself JSON, as a string) carries title/content/useBase64Icon
# etc. No QtWebSockets QML module is installed here and no installs are
# allowed for this fix, so this is the whole server: python3 stdlib only, no
# third-party deps, no pip.
#
# This process only ever emits detected "ring" events, one JSON line each, to
# stdout -- never message content, never anything else. Services/DiscordCall.qml
# owns and restarts this as a Quickshell Process and reads stdout line by line.
# Everything else (handshake noise, malformed frames, refused origins) goes to
# stderr, and never includes notification content even there.
#
# Threads, not asyncio/selectors-in-one-loop: this only ever expects one or
# two short-lived Vencord sockets, so a plain thread-per-connection accept
# loop is simpler than an event loop for the payoff here, and each thread's
# blocking recv naturally serializes that one connection's frames without any
# shared state beyond the print lock.
import base64
import hashlib
import json
import socket
import struct
import sys
import threading

HOST = "127.0.0.1"
PORT = 42070

ALLOWED_ORIGINS = {
    "https://discord.com",
    "https://ptb.discord.com",
    "https://canary.discord.com",
}

WS_MAGIC = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

# Frame/handshake safety caps -- this only ever needs to carry one small
# call-notification envelope, so anything bigger is someone else on
# 127.0.0.1 or a misbehaving client, not a real Vencord frame.
MAX_HEADER_BYTES = 8192
MAX_FRAME_BYTES = 65536
# Vencord holds one socket open; anything past this many at once is a local
# flood, refused on accept rather than given a thread each.
MAX_CLIENTS = 8
RECV_CHUNK = 4096

_stdout_lock = threading.Lock()
_client_slots = threading.BoundedSemaphore(MAX_CLIENTS)


def _emit(name):
    # The only thing this process ever prints to stdout, one line, flushed
    # immediately so the Quickshell Process reading it sees it right away.
    line = json.dumps({"event": "ring", "name": name})
    with _stdout_lock:
        sys.stdout.write(line + "\n")
        sys.stdout.flush()


def _log(msg):
    # Diagnostics only -- stderr, never notification content.
    print(msg, file=sys.stderr, flush=True)


def _recv_exact(sock, n):
    buf = bytearray()
    while len(buf) < n:
        chunk = sock.recv(min(RECV_CHUNK, n - len(buf)))
        if not chunk:
            return None
        buf.extend(chunk)
    return bytes(buf)


def _recv_until_headers_end(sock):
    # Handshake is plain HTTP; read until the blank line, capped so a client
    # that never sends one can't grow this buffer forever.
    buf = bytearray()
    while b"\r\n\r\n" not in buf:
        if len(buf) > MAX_HEADER_BYTES:
            return None
        chunk = sock.recv(RECV_CHUNK)
        if not chunk:
            return None
        buf.extend(chunk)
    return bytes(buf)


def _parse_headers(head_bytes):
    try:
        text = head_bytes.decode("iso-8859-1")
    except UnicodeDecodeError:
        return None, None
    lines = text.split("\r\n")
    if not lines or not lines[0].startswith("GET "):
        return None, None
    headers = {}
    for line in lines[1:]:
        if not line:
            continue
        if ":" not in line:
            return None, None
        k, _, v = line.partition(":")
        headers[k.strip().lower()] = v.strip()
    return lines[0], headers


def _handshake(sock):
    head = _recv_until_headers_end(sock)
    if head is None:
        return False

    request_line, headers = _parse_headers(head.split(b"\r\n\r\n", 1)[0])
    if request_line is None:
        return False

    if headers.get("upgrade", "").lower() != "websocket":
        return False
    if "upgrade" not in headers.get("connection", "").lower():
        return False
    ws_key = headers.get("sec-websocket-key")
    if not ws_key:
        return False

    origin = headers.get("origin", "")
    if origin not in ALLOWED_ORIGINS:
        _log(f"rejected: bad origin ({origin!r})")
        return False

    accept = base64.b64encode(
        hashlib.sha1((ws_key + WS_MAGIC).encode("ascii")).digest()
    ).decode("ascii")

    response = (
        "HTTP/1.1 101 Switching Protocols\r\n"
        "Upgrade: websocket\r\n"
        "Connection: Upgrade\r\n"
        f"Sec-WebSocket-Accept: {accept}\r\n"
        "\r\n"
    )
    sock.sendall(response.encode("ascii"))
    return True


# Opcodes
OP_CONT = 0x0
OP_TEXT = 0x1
OP_BIN = 0x2
OP_CLOSE = 0x8
OP_PING = 0x9
OP_PONG = 0xA


def _recv_frame(sock):
    # Returns (opcode, payload_bytes) or None on EOF/malformed/too-large.
    header = _recv_exact(sock, 2)
    if header is None:
        return None
    b0, b1 = header[0], header[1]
    fin = (b0 & 0x80) != 0
    opcode = b0 & 0x0F
    masked = (b1 & 0x80) != 0
    length = b1 & 0x7F

    # A real browser client always masks (RFC 6455 5.1); refuse anything that
    # doesn't rather than try to make sense of it.
    if not masked:
        return None

    if length == 126:
        ext = _recv_exact(sock, 2)
        if ext is None:
            return None
        length = struct.unpack("!H", ext)[0]
    elif length == 127:
        ext = _recv_exact(sock, 8)
        if ext is None:
            return None
        length = struct.unpack("!Q", ext)[0]

    if length > MAX_FRAME_BYTES:
        return None

    mask_key = _recv_exact(sock, 4)
    if mask_key is None:
        return None

    payload_masked = _recv_exact(sock, length)
    if payload_masked is None:
        return None

    payload = bytearray(payload_masked)
    for i in range(len(payload)):
        payload[i] ^= mask_key[i % 4]

    # Fragmented frames are unnecessary for this protocol's tiny single-shot
    # messages -- treat anything not FIN as malformed rather than reassemble.
    if not fin:
        return None

    return opcode, bytes(payload)


def _send_frame(sock, opcode, payload=b""):
    length = len(payload)
    if length <= 125:
        header = struct.pack("!BB", 0x80 | opcode, length)
    elif length < 65536:
        header = struct.pack("!BBH", 0x80 | opcode, 126, length)
    else:
        header = struct.pack("!BBQ", 0x80 | opcode, 127, length)
    sock.sendall(header + payload)


def _handle_ring_envelope(text):
    # Parses the Vencord XSOverlay envelope described in the header comment
    # and emits a ring event only for a genuine incoming-call notification --
    # never for a message notification (useBase64Icon:true), which uses the
    # exact same outer shape.
    try:
        outer = json.loads(text)
    except (ValueError, TypeError):
        return
    if not isinstance(outer, dict):
        return
    if outer.get("command") != "SendNotification":
        return

    raw = outer.get("jsonData")
    if not isinstance(raw, str):
        return
    try:
        data = json.loads(raw)
    except (ValueError, TypeError):
        return
    if not isinstance(data, dict):
        return

    if data.get("content") != "Incoming call":
        return
    if data.get("useBase64Icon") is not False:
        return

    title = data.get("title")
    if not isinstance(title, str):
        return
    suffix = " is calling you..."
    if not title.endswith(suffix):
        return

    name = title[: -len(suffix)]
    _emit(name)


def _serve_client(sock, addr):
    try:
        sock.settimeout(30)
        if not _handshake(sock):
            try:
                sock.close()
            except OSError:
                pass
            return

        while True:
            frame = _recv_frame(sock)
            if frame is None:
                break
            opcode, payload = frame

            if opcode == OP_TEXT:
                try:
                    text = payload.decode("utf-8")
                except UnicodeDecodeError:
                    break
                _handle_ring_envelope(text)
            elif opcode == OP_PING:
                _send_frame(sock, OP_PONG, payload)
            elif opcode == OP_CLOSE:
                _send_frame(sock, OP_CLOSE, payload[:125])
                break
            elif opcode in (OP_BIN, OP_CONT, OP_PONG):
                continue
            else:
                break
    except (OSError, socket.timeout):
        pass
    finally:
        try:
            sock.close()
        except OSError:
            pass


def _serve_slot(sock, addr):
    try:
        _serve_client(sock, addr)
    finally:
        _client_slots.release()


def main():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        server.bind((HOST, PORT))
    except OSError as e:
        _log(f"bind failed on {HOST}:{PORT}: {e}")
        sys.exit(1)
    server.listen(16)
    _log(f"listening on {HOST}:{PORT}")

    try:
        while True:
            try:
                client, addr = server.accept()
            except OSError:
                break
            if not _client_slots.acquire(blocking=False):
                client.close()
                continue
            t = threading.Thread(target=_serve_slot, args=(client, addr), daemon=True)
            t.start()
    finally:
        server.close()


if __name__ == "__main__":
    main()
