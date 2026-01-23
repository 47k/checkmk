#!/usr/bin/env python3

# Created by Check_MK Agent Bakery.
# This file is managed via WATO, do not edit manually or you
# lose your changes next time when you update the agent.

# Version 0.1 - Manuel Michalski <www.47k.de>
# Date: 23.01.2026
# Last Change: 23.01.2026
# Description: Switch linet_php_fpm_status agent plugin from HTTP(curl) to direct FastCGI socket requests; avoids webserver redirects and removes zsh dependency

import glob
import json
import os
import re
import socket
import struct
import sys
from typing import Dict, Optional, Tuple, Union

# ---------- FastCGI minimal client (stdlib only) ----------

SocketSpec = Union[str, Tuple[str, int]]  # unix socket path OR (host,port)

class FCGIClient:
    FCGI_VERSION = 1
    FCGI_BEGIN_REQUEST = 1
    FCGI_PARAMS = 4
    FCGI_STDIN = 5
    FCGI_STDOUT = 6
    FCGI_STDERR = 7
    FCGI_END_REQUEST = 3
    FCGI_RESPONDER = 1

    def __init__(self, sock: SocketSpec, timeout: float = 5.0) -> None:
        if isinstance(sock, tuple):
            self.s = socket.create_connection(sock, timeout=timeout)
        else:
            self.s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            self.s.settimeout(timeout)
            self.s.connect(sock)
        self.request_id = 1

    def _rec(self, rec_type: int, content: bytes) -> bytes:
        clen = len(content)
        pad = (8 - (clen % 8)) % 8
        header = struct.pack("!BBHHBB", self.FCGI_VERSION, rec_type, self.request_id, clen, pad, 0)
        return header + content + (b"\x00" * pad)

    @staticmethod
    def _nvpair(name: str, value: str) -> bytes:
        n = name.encode("utf-8")
        v = value.encode("utf-8")

        def enc_len(l: int) -> bytes:
            if l < 128:
                return bytes([l])
            return struct.pack("!I", l | 0x80000000)

        return enc_len(len(n)) + enc_len(len(v)) + n + v

    def request(self, params: Dict[str, str]) -> bytes:
        # BEGIN_REQUEST
        begin = struct.pack("!HB5x", self.FCGI_RESPONDER, 0)
        self.s.sendall(self._rec(self.FCGI_BEGIN_REQUEST, begin))

        # PARAMS
        payload = b"".join(self._nvpair(k, v) for k, v in params.items())
        self.s.sendall(self._rec(self.FCGI_PARAMS, payload))
        self.s.sendall(self._rec(self.FCGI_PARAMS, b""))  # end params

        # empty STDIN
        self.s.sendall(self._rec(self.FCGI_STDIN, b""))
        self.s.sendall(self._rec(self.FCGI_STDIN, b""))  # end stdin

        stdout = b""
        stderr = b""

        while True:
            hdr = self.s.recv(8)
            if len(hdr) < 8:
                break
            ver, rtype, rid, rlen, pad, _ = struct.unpack("!BBHHBB", hdr)
            content = b""
            while len(content) < rlen:
                chunk = self.s.recv(rlen - len(content))
                if not chunk:
                    break
                content += chunk
            if pad:
                _ = self.s.recv(pad)

            if rtype == self.FCGI_STDOUT:
                stdout += content
            elif rtype == self.FCGI_STDERR:
                stderr += content
            elif rtype == self.FCGI_END_REQUEST:
                break

        self.s.close()

        # If php-fpm sends error payload, keep quiet (agent plugin should be resilient)
        # You can uncomment for debugging:
        # if stderr: sys.stderr.write(stderr.decode("utf-8", "ignore") + "\n")
        return stdout

# ---------- Pool config parsing (Debian-style pool.d/*.conf) ----------

RE_COMMENT = re.compile(r"^\s*[;#]")
RE_STATUS  = re.compile(r"^\s*pm\.status_path\s*=\s*(\S+)\s*$")
RE_LISTEN  = re.compile(r"^\s*listen\s*=\s*(\S+)\s*$")

def parse_pool_file(path: str) -> Tuple[Optional[str], Optional[str]]:
    status = None
    listen = None
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                if RE_COMMENT.match(line):
                    continue
                m = RE_STATUS.match(line)
                if m:
                    status = m.group(1).strip("\"'")
                    continue
                m = RE_LISTEN.match(line)
                if m:
                    listen = m.group(1).strip("\"'")
                    continue
    except OSError:
        return None, None
    return listen, status

def listen_to_socket_spec(listen: str) -> Optional[SocketSpec]:
    # unix socket
    if listen.startswith("/"):
        return listen

    # "127.0.0.1:9000" or "[::1]:9000"
    m = re.match(r"^\[?([0-9a-fA-F:.]+)\]?:([0-9]{1,5})$", listen)
    if m:
        host = m.group(1)
        port = int(m.group(2))
        return (host, port)

    # "9000" -> assume localhost
    if listen.isdigit():
        port = int(listen)
        return ("127.0.0.1", port)

    return None

def php_version_from_path(path: str) -> str:
    # /etc/php/8.3/fpm/pool.d/collab.conf -> "8.3"
    p = path.split("/")
    try:
        idx = p.index("php")
        return p[idx + 1]
    except Exception:
        return "unknown"

# ---------- Main ----------

def main() -> int:
    pool_files = glob.glob("/etc/php/*/fpm/pool.d/*.conf")
    entries = []

    for pf in pool_files:
        listen, status = parse_pool_file(pf)
        if not listen or not status:
            continue
        sock = listen_to_socket_spec(listen)
        if not sock:
            continue
        entries.append((php_version_from_path(pf), sock, status))

    if not entries:
        return 0

    sys.stdout.write("<<<linet_php_fpm_status>>>\n")

    for phpver, sock, status_path in entries:
        try:
            client = FCGIClient(sock, timeout=5.0)
            raw = client.request({
                "SCRIPT_NAME": status_path,
                "SCRIPT_FILENAME": status_path,
                "QUERY_STRING": "json",
                "REQUEST_METHOD": "GET",
                "SERVER_PROTOCOL": "HTTP/1.1",
                "GATEWAY_INTERFACE": "CGI/1.1",
                "SERVER_NAME": "localhost",
                "SERVER_PORT": "80",
            })

            # php-fpm returns HTTP-ish headers + body; split at empty line
            if b"\r\n\r\n" in raw:
                body = raw.split(b"\r\n\r\n", 1)[1]
            elif b"\n\n" in raw:
                body = raw.split(b"\n\n", 1)[1]
            else:
                body = raw

            body = body.strip()
            if not body.startswith(b"{"):
                continue

            data = json.loads(body.decode("utf-8", "ignore"))
            data["_php_version"] = phpver

            # compact single-line JSON (like LINET script did)
            sys.stdout.write(json.dumps(data, separators=(",", ":"), ensure_ascii=False) + "\n")

        except Exception:
            # agent plugin should never break the agent
            continue

    return 0

if __name__ == "__main__":
    raise SystemExit(main())
