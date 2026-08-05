#!/usr/bin/env python3
"""OmniBoard reference clock provider (OPP over stdio).

Language-agnostic demo: push a com.omniboard.clock.now item every second.
Run via flake Python:

  nix develop -c python providers/clock/provider.py
"""

from __future__ import annotations

import json
import os
import sys
import time
from datetime import datetime, timezone
from typing import Any


def read_message() -> dict[str, Any] | None:
    headers: dict[str, str] = {}
    while True:
        line = sys.stdin.buffer.readline()
        if not line:
            return None
        if line in (b"\r\n", b"\n"):
            break
        key, _, value = line.decode("utf-8").partition(":")
        headers[key.strip().lower()] = value.strip()
    length = int(headers.get("content-length", "0"))
    body = sys.stdin.buffer.read(length)
    if not body:
        return None
    return json.loads(body.decode("utf-8"))


def write_message(msg: dict[str, Any]) -> None:
    body = json.dumps(msg, separators=(",", ":")).encode("utf-8")
    sys.stdout.buffer.write(f"Content-Length: {len(body)}\r\n\r\n".encode("ascii"))
    sys.stdout.buffer.write(body)
    sys.stdout.buffer.flush()


def main() -> None:
    instance_id = os.environ.get("OMNIBOARD_INSTANCE_ID", "inst_clock_1")
    revision = 0

    # Handshake
    req = read_message()
    if not req or req.get("method") != "initialize":
        sys.stderr.write("expected initialize\n")
        sys.exit(1)
    write_message(
        {
            "jsonrpc": "2.0",
            "id": req["id"],
            "result": {
                "oppVersion": "1.0",
                "serverInfo": {"name": "clock", "version": "0.1.0"},
                "capabilities": {
                    "items": {"push": True, "pull": False},
                    "actions": {"execute": False},
                    "cache": {"hints": True},
                    "encoding": ["json"],
                },
            },
        }
    )
    # Wait for initialized notification (optional drain)
    _ = read_message()

    write_message(
        {
            "jsonrpc": "2.0",
            "method": "provider/status",
            "params": {"state": "ready"},
        }
    )

    while True:
        revision += 1
        now = datetime.now(timezone.utc)
        iso = now.isoformat().replace("+00:00", "Z")
        label = now.strftime("%H:%M:%S")
        write_message(
            {
                "jsonrpc": "2.0",
                "method": "items/changed",
                "params": {
                    "providerInstanceId": instance_id,
                    "delta": {
                        "upsert": [
                            {
                                "id": {
                                    "providerInstanceId": instance_id,
                                    "localId": "now",
                                },
                                "type": "com.omniboard.clock.now",
                                "revision": revision,
                                "updatedAt": iso,
                                "payload": {"unix": int(now.timestamp()), "iso": iso},
                                "render": {
                                    "schemaVersion": "1.0",
                                    "surfaceHints": ["menuBar", "widgetSmall", "canvas"],
                                    "root": {
                                        "type": "HStack",
                                        "children": [
                                            {
                                                "type": "Symbol",
                                                "name": "clock",
                                                "accessibilityLabel": "Clock",
                                            },
                                            {
                                                "type": "Text",
                                                "value": label,
                                                "style": "mono",
                                            },
                                        ],
                                    },
                                },
                                "tags": ["demo", "clock"],
                                "asOf": iso,
                            }
                        ],
                        "delete": [],
                    },
                    "cache": {"ttlMs": 2000, "tags": ["clock"]},
                },
            }
        )
        time.sleep(1.0)


if __name__ == "__main__":
    try:
        main()
    except BrokenPipeError:
        pass
