#!/usr/bin/env python3
"""Repository-level validation for Funplay MCP for Godot."""

from __future__ import annotations

import configparser
import json
import pathlib
import re
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]
PLUGIN_CFG = ROOT / "addons" / "funplay_mcp" / "plugin.cfg"
SERVER = ROOT / "addons" / "funplay_mcp" / "core" / "funplay_mcp_server.gd"
REQUEST_HANDLER = ROOT / "addons" / "funplay_mcp" / "core" / "funplay_mcp_request_handler.gd"
TOOL_REGISTRY = ROOT / "addons" / "funplay_mcp" / "core" / "funplay_tool_registry.gd"
CORE_TOOLS = ROOT / "addons" / "funplay_mcp" / "core" / "funplay_core_tools.gd"
SERVER_JSON = ROOT / "server.json"
WRAPPER_PACKAGE_JSON = ROOT / "stdio-wrapper" / "package.json"
WRAPPER_BIN = ROOT / "stdio-wrapper" / "bin" / "funplay-godot-mcp.js"


def read_text(path: pathlib.Path) -> str:
    return path.read_text(encoding="utf-8")


def add_required_file_errors(errors: list[str]) -> None:
    required_files = [
        ROOT / "README.md",
        ROOT / "README_CN.md",
        ROOT / "LICENSE",
        ROOT / "CHANGELOG.md",
        ROOT / "CONTRIBUTING.md",
        ROOT / "RELEASE_CHECKLIST.md",
        PLUGIN_CFG,
        ROOT / "addons" / "funplay_mcp" / "plugin.gd",
        ROOT / "addons" / "funplay_mcp" / "core" / "funplay_project_skill_manager.gd",
        ROOT / "addons" / "funplay_mcp" / "core" / "funplay_update_checker.gd",
        ROOT / "addons" / "funplay_mcp" / "runtime" / "funplay_mcp_runtime_bridge.gd",
        ROOT / "scripts" / "package_release.py",
        ROOT / ".github" / "workflows" / "release.yml",
        SERVER_JSON,
        WRAPPER_PACKAGE_JSON,
        WRAPPER_BIN,
        ROOT / "stdio-wrapper" / "README.md",
    ]
    for path in required_files:
        if not path.exists():
            errors.append(f"Missing required file: {path.relative_to(ROOT)}")


def add_plugin_cfg_errors(errors: list[str]) -> str:
    if not PLUGIN_CFG.exists():
        return ""

    parser = configparser.ConfigParser()
    try:
        parser.read(PLUGIN_CFG, encoding="utf-8")
    except Exception as exc:  # pragma: no cover - defensive CI reporting
        errors.append(f"plugin.cfg is not valid INI: {exc}")
        return ""

    if "plugin" not in parser:
        errors.append("plugin.cfg is missing [plugin] section")
        return ""

    for key in ("name", "description", "author", "version", "script"):
        if not parser["plugin"].get(key):
            errors.append(f"plugin.cfg is missing required key: {key}")

    return parser["plugin"].get("version", "").strip('"')


def add_junk_file_errors(errors: list[str]) -> None:
    forbidden_names = {".DS_Store", "export_presets.cfg"}
    forbidden_dirs = {".idea", ".godot", ".import", "Library", "Temp", "temp", "tmp"}
    forbidden_paths: list[str] = []
    for path in ROOT.rglob("*"):
        if ".git" in path.parts:
            continue
        if path.name in forbidden_names or any(part in forbidden_dirs for part in path.parts):
            forbidden_paths.append(str(path.relative_to(ROOT)))

    if forbidden_paths:
        errors.append("Repository contains local junk files:\n- " + "\n- ".join(sorted(forbidden_paths)))


def add_version_errors(errors: list[str], plugin_version: str) -> None:
    if not SERVER.exists():
        return

    server_text = read_text(SERVER)
    match = re.search(r'const SERVER_VERSION\s*(?::=|=)\s*"([^"]+)"', server_text)
    if not match:
        errors.append("funplay_mcp_server.gd is missing SERVER_VERSION")
        return

    server_version = match.group(1)
    if plugin_version and plugin_version != server_version:
        errors.append(f"Version mismatch: plugin.cfg={plugin_version}, server={server_version}")

    changelog = read_text(ROOT / "CHANGELOG.md") if (ROOT / "CHANGELOG.md").exists() else ""
    if server_version and f"## [{server_version}]" not in changelog:
        errors.append(f"CHANGELOG.md does not include a release section for {server_version}")

    add_registry_metadata_errors(errors, server_version)


def add_registry_metadata_errors(errors: list[str], server_version: str) -> None:
    if not SERVER_JSON.exists() or not WRAPPER_PACKAGE_JSON.exists():
        return

    try:
        server_data = json.loads(read_text(SERVER_JSON))
    except Exception as exc:
        errors.append(f"server.json is not valid JSON: {exc}")
        return

    expected_name = "io.github.FunplayAI/funplay-godot-mcp"
    if server_data.get("name") != expected_name:
        errors.append(f"server.json name should be {expected_name}")
    if server_version and server_data.get("version") != server_version:
        errors.append(f"server.json version {server_data.get('version')} does not match {server_version}")

    packages = server_data.get("packages", [])
    if not isinstance(packages, list) or len(packages) != 1:
        errors.append("server.json should contain exactly one package entry")
        packages = []

    if packages:
        package = packages[0]
        if package.get("registryType") != "npm":
            errors.append("server.json package registryType should be npm")
        if package.get("identifier") != "funplay-godot-mcp":
            errors.append("server.json package identifier should be funplay-godot-mcp")
        if server_version and package.get("version") != server_version:
            errors.append(f"server.json package version {package.get('version')} does not match {server_version}")
        transport = package.get("transport", {})
        if not isinstance(transport, dict) or transport.get("type") != "stdio":
            errors.append("server.json package transport type should be stdio")

    try:
        wrapper_data = json.loads(read_text(WRAPPER_PACKAGE_JSON))
    except Exception as exc:
        errors.append(f"stdio-wrapper/package.json is not valid JSON: {exc}")
        return

    if wrapper_data.get("name") != "funplay-godot-mcp":
        errors.append("stdio-wrapper package name should be funplay-godot-mcp")
    if wrapper_data.get("mcpName") != expected_name:
        errors.append("stdio-wrapper package mcpName must match server.json name")
    if server_version and wrapper_data.get("version") != server_version:
        errors.append(f"stdio-wrapper package version {wrapper_data.get('version')} does not match {server_version}")

    bin_map = wrapper_data.get("bin", {})
    if not isinstance(bin_map, dict) or bin_map.get("funplay-godot-mcp") != "bin/funplay-godot-mcp.js":
        errors.append("stdio-wrapper package bin should expose funplay-godot-mcp")


def add_protocol_errors(errors: list[str]) -> None:
    if not REQUEST_HANDLER.exists():
        return

    text = read_text(REQUEST_HANDLER)
    match = re.search(r"SUPPORTED_PROTOCOL_VERSIONS\s*(?::=|=)\s*\[(.*?)\]", text, re.S)
    if not match:
        errors.append("SUPPORTED_PROTOCOL_VERSIONS is missing")
        return

    versions = re.findall(r'"(\d{4}-\d{2}-\d{2})"', match.group(1))
    if not versions:
        errors.append("SUPPORTED_PROTOCOL_VERSIONS is empty")
        return
    if versions[0] != "2025-11-25":
        errors.append(f"Default MCP protocol version should be 2025-11-25, got {versions[0]}")


def add_tool_registry_errors(errors: list[str]) -> None:
    if not TOOL_REGISTRY.exists() or not CORE_TOOLS.exists():
        return

    registry_text = read_text(TOOL_REGISTRY)
    core_text = read_text(CORE_TOOLS)
    registrations = re.findall(
        r'_register_tool\(\s*"([^"]+)".*?,\s*"([^"]+)"\s*,\s*\[([^\]]*)\]',
        registry_text,
        re.S,
    )
    if not registrations:
        errors.append("No tool registrations found")
        return

    tool_names = [name for name, _, _ in registrations]
    duplicate_names = sorted({name for name in tool_names if tool_names.count(name) > 1})
    if duplicate_names:
        errors.append("Duplicate tool registrations: " + ", ".join(duplicate_names))

    method_names = set(re.findall(r"^func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(", core_text, re.M))
    missing_handlers = sorted({method for _, method, _ in registrations if method not in method_names})
    if missing_handlers:
        errors.append("Registered tool handlers are missing: " + ", ".join(missing_handlers))

    bad_profiles = []
    for name, _, profile_text in registrations:
        profiles = re.findall(r'"([^"]+)"', profile_text)
        if not profiles or any(profile not in {"core", "full"} for profile in profiles):
            bad_profiles.append(name)
    if bad_profiles:
        errors.append("Tools have invalid profile declarations: " + ", ".join(sorted(bad_profiles)))

    add_documented_tool_count_errors(errors, len(registrations))


def add_documented_tool_count_errors(errors: list[str], actual_count: int) -> None:
    for relative in ("README.md", "README_CN.md"):
        path = ROOT / relative
        if not path.exists():
            continue

        text = read_text(path)
        documented_counts = {
            int(value)
            for value in re.findall(r"\*\*(\d+)\s+(?:Built-in Tools|registered tools|个内置工具|个注册工具函数)", text)
        }
        if documented_counts and documented_counts != {actual_count}:
            errors.append(
                f"{relative} documented tool count {sorted(documented_counts)} does not match actual {actual_count}"
            )


def main() -> int:
    errors: list[str] = []
    add_required_file_errors(errors)
    plugin_version = add_plugin_cfg_errors(errors)
    add_junk_file_errors(errors)
    add_version_errors(errors, plugin_version)
    add_protocol_errors(errors)
    add_tool_registry_errors(errors)

    if errors:
        print("Validation failed:\n")
        for error in errors:
            print(f"- {error}")
        return 1

    print("Repository validation passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
