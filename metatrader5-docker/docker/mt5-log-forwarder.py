#!/usr/bin/env python3
"""Forward MT5 journal files to container stdout as redacted JSON lines."""

from __future__ import annotations

import codecs
import json
import os
import re
import sys
import time
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path


def env_bool(name: str, default: bool) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    return value.lower() in {"1", "true", "yes", "on"}


def emit(event: str, **fields: object) -> None:
    payload = {
        "timestamp": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "component": "mt5-log-forwarder",
        "event": event,
        **fields,
    }
    print(json.dumps(payload, ensure_ascii=False), flush=True)


PASSWORD_PATTERN = re.compile(
    r"(?i)\b(password|passwd|pwd)\s*[:=]\s*([^\s,;]+)"
)


@dataclass
class LogState:
    path: Path
    offset: int = 0
    encoding: str = "utf-8"
    decoder: codecs.IncrementalDecoder | None = None
    partial: str = ""
    initialized: bool = False

    def reset(self, encoding: str) -> None:
        self.offset = 0
        self.encoding = encoding
        decoder_type = codecs.getincrementaldecoder(encoding)
        self.decoder = decoder_type(errors="replace")
        self.partial = ""
        self.initialized = False


def detect_encoding(path: Path) -> str:
    try:
        sample = path.read_bytes()[:512]
    except OSError:
        return "utf-8"
    if sample.startswith(b"\xff\xfe"):
        return "utf-16-le"
    if sample.startswith(b"\xfe\xff"):
        return "utf-16-be"
    if sample and sample.count(b"\x00") / len(sample) > 0.15:
        return "utf-16-le"
    return "utf-8"


def candidate_log_directories(root: Path) -> set[Path]:
    """Return known MT5 log locations without rescanning the full Wine prefix."""
    directories: set[Path] = set()
    terminal_patterns = (
        "drive_c/Program Files/*/terminal64.exe",
        "drive_c/Program Files/*/*/terminal64.exe",
        "drive_c/Program Files (x86)/*/terminal64.exe",
    )
    for pattern in terminal_patterns:
        for terminal in root.glob(pattern):
            base = terminal.parent
            directories.update(
                {
                    base / "Logs",
                    base / "Logs" / "Crash",
                    base / "MQL5" / "Logs",
                    base / "Tester" / "logs",
                }
            )

    data_pattern = "drive_c/users/*/AppData/Roaming/MetaQuotes/Terminal/*"
    for base in root.glob(data_pattern):
        directories.update(
            {
                base / "Logs",
                base / "Logs" / "Crash",
                base / "MQL5" / "Logs",
                base / "Tester" / "logs",
            }
        )
    return directories


def discover(root: Path, max_files: int) -> list[Path]:
    paths: set[Path] = set()
    try:
        for directory in candidate_log_directories(root):
            if not directory.is_dir():
                continue
            for path in directory.glob("*.log*"):
                if path.is_file():
                    paths.add(path)
    except OSError:
        return []
    ordered = list(paths)
    ordered.sort(key=lambda item: item.stat().st_mtime if item.exists() else 0, reverse=True)
    return ordered[:max_files]


def redact(message: str, enabled: bool) -> str:
    if not enabled:
        return message
    return PASSWORD_PATTERN.sub(lambda match: f"{match.group(1)}=<redacted>", message)


def emit_line(path: Path, root: Path, line: str, redaction: bool) -> None:
    cleaned = line.lstrip("\ufeff").rstrip("\r\n")
    if not cleaned:
        return
    try:
        source = str(path.relative_to(root))
    except ValueError:
        source = str(path)
    emit("journal", source=source, message=redact(cleaned, redaction))


def read_updates(
    state: LogState,
    root: Path,
    initial_tail_lines: int,
    redaction: bool,
) -> None:
    try:
        size = state.path.stat().st_size
    except OSError:
        return

    if size < state.offset:
        state.reset(detect_encoding(state.path))

    if state.decoder is None:
        state.reset(detect_encoding(state.path))

    try:
        with state.path.open("rb") as stream:
            stream.seek(state.offset)
            chunk = stream.read()
            state.offset = stream.tell()
    except OSError:
        return

    if not chunk:
        return

    assert state.decoder is not None
    text = state.partial + state.decoder.decode(chunk, final=False)
    pieces = text.splitlines(keepends=True)
    complete: list[str] = []
    state.partial = ""
    for index, piece in enumerate(pieces):
        if piece.endswith(("\n", "\r")):
            complete.append(piece)
        elif index == len(pieces) - 1:
            state.partial = piece
        else:
            complete.append(piece)

    if not state.initialized:
        complete = complete[-initial_tail_lines:] if initial_tail_lines > 0 else []
        state.initialized = True

    for line in complete:
        emit_line(state.path, root, line, redaction)


def main() -> int:
    if not env_bool("MT5_LOG_FORWARDING", True):
        emit("disabled")
        while True:
            time.sleep(3600)

    root = Path(os.environ.get("WINEPREFIX", "/home/trader/.mt5"))
    tail_lines = max(0, int(os.getenv("MT5_LOG_TAIL_LINES", "20")))
    max_files = max(1, int(os.getenv("MT5_LOG_MAX_FILES", "20")))
    scan_interval = max(0.5, float(os.getenv("MT5_LOG_SCAN_INTERVAL", "2")))
    redaction = env_bool("MT5_LOG_REDACT", True)
    states: dict[Path, LogState] = {}

    emit(
        "started",
        root=str(root),
        initial_tail_lines=tail_lines,
        max_files=max_files,
        redaction=redaction,
    )

    while True:
        for path in discover(root, max_files):
            if path not in states:
                states[path] = LogState(path=path)
            read_updates(states[path], root, tail_lines, redaction)
        time.sleep(scan_interval)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        sys.exit(0)
