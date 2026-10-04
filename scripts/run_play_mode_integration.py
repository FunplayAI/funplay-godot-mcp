#!/usr/bin/env python3
"""Exercise MCP play-mode control through a real Godot editor and two game instances."""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request


ROOT = pathlib.Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "tests" / "integration" / "play_mode"
PROJECT_NAME = "Funplay MCP Play Mode Integration"
AUTH_TOKEN = "funplay-play-mode-integration-token"


def available_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


def app_userdata_dir(home: pathlib.Path) -> pathlib.Path:
    if sys.platform == "darwin":
        return home / "Library" / "Application Support" / "Godot" / "app_userdata" / PROJECT_NAME
    if os.name == "nt":
        return home / "AppData" / "Roaming" / "Godot" / "app_userdata" / PROJECT_NAME
    return home / ".local" / "share" / "godot" / "app_userdata" / PROJECT_NAME


def write_editor_configuration(project: pathlib.Path, home: pathlib.Path, port: int) -> None:
    metadata = project / ".godot" / "editor" / "project_metadata.cfg"
    metadata.parent.mkdir(parents=True, exist_ok=True)
    metadata.write_text(
        "[debug_options]\n\n"
        "multiple_instances_enabled=true\n"
        "run_instance_count=2\n"
        'run_instances_config=Array[Dictionary]([{"arguments":"--headless -- creative","features":"","override_args":true,"override_features":false}, {"arguments":"--headless -- client","features":"","override_args":true,"override_features":false}])\n',
        encoding="utf-8",
    )

    settings_dir = app_userdata_dir(home)
    settings_dir.mkdir(parents=True, exist_ok=True)
    (settings_dir / "funplay_mcp_settings.cfg").write_text(
        "[server]\n\n"
        "enabled=true\n"
        f"port={port}\n"
        f'auth_token="{AUTH_TOKEN}"\n'
        'tool_profile="core"\n'
        "debug_logging_enabled=true\n"
        "execute_code_safety_checks_enabled=true\n\n"
        "[tools]\n\n"
        "disabled=Array[String]([])\n",
        encoding="utf-8",
    )


def rpc(port: int, request_id: int | float | str, tool_name: str, arguments: dict | None = None, *, method: str = "tools/call") -> dict:
    payload = {
        "jsonrpc": "2.0",
        "id": request_id,
        "method": method,
        "params": {"name": tool_name, "arguments": arguments or {}} if method == "tools/call" else {},
    }
    request = urllib.request.Request(
        f"http://127.0.0.1:{port}/",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {AUTH_TOKEN}",
            "Content-Type": "application/json",
            "MCP-Protocol-Version": "2025-11-25",
        },
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=10) as response:
        body = response.read()
    if not body:
        raise AssertionError(f"{tool_name} returned an empty HTTP body")
    parsed = json.loads(body)
    if parsed.get("id") != request_id or type(parsed.get("id")) is not type(request_id):
        raise AssertionError(f"{tool_name} returned the wrong request id: {parsed}")
    return parsed


def structured(response: dict) -> dict:
    return response.get("result", {}).get("structuredContent", {})


def wait_for_server(port: int, process: subprocess.Popen, timeout: float = 20.0) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise AssertionError(f"Godot editor exited before MCP startup (exit {process.returncode})")
        try:
            with urllib.request.urlopen(f"http://127.0.0.1:{port}/health", timeout=0.5) as response:
                if response.status == 200:
                    return
        except (OSError, urllib.error.URLError):
            time.sleep(0.1)
    raise AssertionError("Timed out waiting for the MCP health endpoint")


def wait_for_state(port: int, expected_playing: bool, start_id: int, timeout: float = 10.0) -> tuple[dict, int]:
    deadline = time.monotonic() + timeout
    request_id = start_id
    last_state: dict = {}
    while time.monotonic() < deadline:
        response = rpc(port, request_id, "get_play_state")
        request_id += 1
        last_state = structured(response)
        if bool(last_state.get("is_playing_scene", False)) == expected_playing and not last_state.get("pending_operation"):
            return last_state, request_id
        time.sleep(0.1)
    raise AssertionError(f"Timed out waiting for play state {expected_playing}: {last_state}")


def wait_for_markers(marker_dir: pathlib.Path, expected: int, timeout: float = 10.0) -> list[dict]:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        paths = sorted(marker_dir.glob("instance_*.json")) if marker_dir.exists() else []
        if len(paths) == expected:
            return [json.loads(path.read_text(encoding="utf-8")) for path in paths]
        time.sleep(0.1)
    paths = sorted(marker_dir.glob("instance_*.json")) if marker_dir.exists() else []
    raise AssertionError(f"Expected {expected} instance markers, found {len(paths)}")


def process_is_alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except OSError:
        return False
    return True


def wait_for_processes_to_exit(pids: list[int], timeout: float = 10.0) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if not any(process_is_alive(pid) for pid in pids):
            return
        time.sleep(0.1)
    alive = [pid for pid in pids if process_is_alive(pid)]
    raise AssertionError(f"Game instances were not stopped: {alive}")


def run(godot: pathlib.Path, keep_temp: bool) -> int:
    temp_context = tempfile.TemporaryDirectory(prefix="funplay-play-mode-")
    temp_root = pathlib.Path(temp_context.name)
    project = temp_root / "project"
    home = temp_root / "home"
    port = available_port()
    log_path = temp_root / "godot-editor.log"

    shutil.copytree(FIXTURE, project)
    shutil.copytree(ROOT / "addons" / "funplay_mcp", project / "addons" / "funplay_mcp")
    write_editor_configuration(project, home, port)

    env = os.environ.copy()
    env["HOME"] = str(home)
    command = [str(godot), "--editor", "--headless", "--path", str(project)]
    log_file = log_path.open("w", encoding="utf-8")
    process = subprocess.Popen(command, env=env, stdout=log_file, stderr=subprocess.STDOUT, text=True)

    failure: Exception | None = None
    try:
        wait_for_server(port, process)

        for request_id in (0, -1, 2.5, "client-1"):
            initialized = rpc(port, request_id, "initialize", method="initialize")
            if initialized.get("result", {}).get("protocolVersion") != "2025-11-25":
                raise AssertionError(f"Initialization did not negotiate the MCP protocol: {initialized}")
            unknown = rpc(port, request_id, "missing_tool")
            if unknown.get("error", {}).get("code") != -32602:
                raise AssertionError(f"Unknown tool did not return a JSON-RPC error: {unknown}")

        refused = rpc(port, 1, "play_main_scene")
        refused_result = structured(refused)
        if not refused.get("result", {}).get("isError", False):
            raise AssertionError(f"Unconfirmed multiple-instance run was not refused: {refused}")
        if refused_result.get("code") != "MULTIPLE_INSTANCES_CONFIRMATION_REQUIRED":
            raise AssertionError(f"Unexpected refusal result: {refused_result}")
        time.sleep(0.3)
        marker_dir = project / "integration_markers"
        if marker_dir.exists() and list(marker_dir.glob("instance_*.json")):
            raise AssertionError("A refused multiple-instance request still launched the game")

        started = rpc(port, 2, "play_main_scene", {"allow_multiple_instances": True})
        started_result = structured(started)
        if started.get("result", {}).get("isError", True) or started_result.get("status") != "scheduled":
            raise AssertionError(f"Confirmed multiple-instance run was not scheduled: {started}")

        running_state, request_id = wait_for_state(port, True, 3)
        run_instances = running_state.get("run_instances", {})
        if run_instances.get("effective_instance_count") != 2:
            raise AssertionError(f"Godot did not report two configured instances: {running_state}")
        if running_state.get("last_operation", {}).get("status") != "completed":
            raise AssertionError(f"Start transition was not confirmed: {running_state}")
        if running_state.get("current_scene_path") != "res://main.tscn":
            raise AssertionError(f"The edited scene path was not reported correctly: {running_state}")
        if not isinstance(running_state.get("open_scenes"), list):
            raise AssertionError(f"Open scenes were not returned as a JSON array: {running_state}")

        markers = wait_for_markers(marker_dir, 2)
        user_args = sorted(arg for marker in markers for arg in marker.get("user_args", []))
        if user_args != ["client", "creative"]:
            raise AssertionError(f"Per-instance arguments were not preserved: {markers}")
        pids = [int(marker["pid"]) for marker in markers]

        duplicate_start = rpc(port, request_id, "play_main_scene")
        request_id += 1
        if structured(duplicate_start).get("status") != "already_running":
            raise AssertionError(f"Repeated play_main_scene was not idempotent: {duplicate_start}")
        time.sleep(0.3)
        if len(list(marker_dir.glob("instance_*.json"))) != 2:
            raise AssertionError("Repeated play_main_scene launched additional instances")

        stopped = rpc(port, request_id, "exit_play_mode")
        request_id += 1
        if stopped.get("result", {}).get("isError", True) or structured(stopped).get("status") != "scheduled":
            raise AssertionError(f"exit_play_mode was not scheduled: {stopped}")
        stopped_state, request_id = wait_for_state(port, False, request_id)
        if stopped_state.get("last_operation", {}).get("status") != "completed":
            raise AssertionError(f"Stop transition was not confirmed: {stopped_state}")
        wait_for_processes_to_exit(pids)

        already_stopped = rpc(port, request_id, "exit_play_mode")
        if structured(already_stopped).get("status") != "already_stopped":
            raise AssertionError(f"Repeated exit_play_mode was not idempotent: {already_stopped}")
    except Exception as exc:
        failure = exc
    finally:
        if process.poll() is None:
            try:
                rpc(port, 999_999, "execute_code", {
                    "code": 'ctx.plugin.get_tree().call_deferred("quit")\nreturn {"scheduled": true}',
                    "safety_checks": False,
                    "include_metadata": False,
                })
                process.wait(timeout=15)
            except Exception:
                process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)
        log_file.close()

    log_text = log_path.read_text(encoding="utf-8", errors="replace")
    if failure is not None:
        log_tail = "\n".join(log_text.splitlines()[-120:])
        print(f"Godot editor log tail:\n{log_tail}", file=sys.stderr)
        raise failure
    forbidden = ["Stack underflow!", "calculated index 0 is out of bounds"]
    found = [message for message in forbidden if message.lower() in log_text.lower()]
    if found:
        raise AssertionError(f"Godot logged the original failure signature: {found}\nLog: {log_path}")

    print(f"play mode integration passed: {godot}")
    if keep_temp:
        kept_path = pathlib.Path(tempfile.mkdtemp(prefix="funplay-play-mode-kept-"))
        shutil.copytree(temp_root, kept_path, dirs_exist_ok=True)
        print(f"kept integration files: {kept_path}")
    temp_context.cleanup()
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, help="Path to a Godot editor executable")
    parser.add_argument("--keep-temp", action="store_true", help="Keep a copy of the isolated project and editor log")
    args = parser.parse_args()
    godot = pathlib.Path(args.godot).expanduser().resolve()
    if not godot.exists():
        print(f"Godot executable not found: {godot}", file=sys.stderr)
        return 2
    try:
        return run(godot, args.keep_temp)
    except Exception as exc:
        print(f"Play mode integration failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
