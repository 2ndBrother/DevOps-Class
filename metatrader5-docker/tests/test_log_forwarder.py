from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).parents[1] / "docker" / "mt5-log-forwarder.py"
SPEC = importlib.util.spec_from_file_location("mt5_log_forwarder", MODULE_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"Unable to load {MODULE_PATH}")
FORWARDER = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = FORWARDER
SPEC.loader.exec_module(FORWARDER)


class LogForwarderTests(unittest.TestCase):
    def test_password_redaction(self) -> None:
        message = "login=100 password=secret; PWD:another status=connected"
        result = FORWARDER.redact(message, enabled=True)
        self.assertEqual(
            result,
            "login=100 password=<redacted>; PWD=<redacted> status=connected",
        )

    def test_encoding_detection(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            utf8 = root / "utf8.log"
            utf16 = root / "utf16.log"
            utf8.write_text("terminal started\n", encoding="utf-8")
            utf16.write_text("terminal started\n", encoding="utf-16")
            self.assertEqual(FORWARDER.detect_encoding(utf8), "utf-8")
            self.assertEqual(FORWARDER.detect_encoding(utf16), "utf-16-le")

    def test_initial_tail_and_appended_line(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            log = root / "terminal.log"
            log.write_text("one\ntwo\npassword=hidden\n", encoding="utf-8")
            state = FORWARDER.LogState(path=log)

            first_output = io.StringIO()
            with contextlib.redirect_stdout(first_output):
                FORWARDER.read_updates(
                    state,
                    root,
                    initial_tail_lines=2,
                    redaction=True,
                )
            first_events = [json.loads(line) for line in first_output.getvalue().splitlines()]
            self.assertEqual([event["message"] for event in first_events], ["two", "password=<redacted>"])

            with log.open("a", encoding="utf-8") as stream:
                stream.write("four\n")
            second_output = io.StringIO()
            with contextlib.redirect_stdout(second_output):
                FORWARDER.read_updates(
                    state,
                    root,
                    initial_tail_lines=2,
                    redaction=True,
                )
            second_events = [json.loads(line) for line in second_output.getvalue().splitlines()]
            self.assertEqual([event["message"] for event in second_events], ["four"])

    def test_log_discovery(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            terminal = root / "drive_c" / "Program Files" / "MetaTrader 5" / "terminal64.exe"
            log = terminal.parent / "Logs" / "20261004.log"
            log.parent.mkdir(parents=True)
            terminal.touch()
            log.write_text("ready\n", encoding="utf-8")
            self.assertIn(log, FORWARDER.discover(root, max_files=20))


if __name__ == "__main__":
    unittest.main()
