#!/usr/bin/env python3
"""Build and validate release artifacts for Funplay MCP for Godot."""

from __future__ import annotations

import argparse
import configparser
import datetime as dt
import hashlib
import json
import pathlib
import re
import shutil
import stat
import sys
import zipfile


ROOT = pathlib.Path(__file__).resolve().parents[1]
PLUGIN_CFG = ROOT / "addons" / "funplay_mcp" / "plugin.cfg"
SERVER = ROOT / "addons" / "funplay_mcp" / "core" / "funplay_mcp_server.gd"
CHANGELOG = ROOT / "CHANGELOG.md"
SERVER_JSON = ROOT / "server.json"
WRAPPER_PACKAGE_JSON = ROOT / "stdio-wrapper" / "package.json"

REPOSITORY = "FunplayAI/funplay-godot-mcp"
REPOSITORY_URL = f"https://github.com/{REPOSITORY}"
PACKAGE_PREFIX = "Funplay.GodotMcp"
ADDON_ROOT = "addons/funplay_mcp"
ALLOWED_ROOT_FILES = {
    "LICENSE",
}
FORBIDDEN_NAMES = {
    ".DS_Store",
    "export_presets.cfg",
}
FORBIDDEN_PARTS = {
    ".git",
    ".github",
    ".godot",
    ".import",
    "Library",
    "Temp",
    "tmp",
    "__pycache__",
    "dist",
    "node_modules",
}


def read_text(path: pathlib.Path) -> str:
    return path.read_text(encoding="utf-8")


def sha256_file(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_plugin_version() -> str:
    parser = configparser.ConfigParser()
    parser.read(PLUGIN_CFG, encoding="utf-8")
    return parser["plugin"].get("version", "").strip('"')


def read_server_version() -> str:
    text = read_text(SERVER)
    match = re.search(r'const SERVER_VERSION\s*(?::=|=)\s*"([^"]+)"', text)
    return match.group(1) if match else ""


def normalize_version(version: str) -> str:
    return version.strip().lstrip("vV")


def add_error(errors: list[str], message: str) -> None:
    errors.append(message)


def validate_version(version: str) -> None:
    errors: list[str] = []
    plugin_version = read_plugin_version()
    server_version = read_server_version()
    if plugin_version != version:
        add_error(errors, f"plugin.cfg version {plugin_version!r} does not match {version!r}")
    if server_version != version:
        add_error(errors, f"SERVER_VERSION {server_version!r} does not match {version!r}")

    if CHANGELOG.exists() and f"## [{version}]" not in read_text(CHANGELOG):
        add_error(errors, f"CHANGELOG.md does not include a release section for {version}")

    if SERVER_JSON.exists():
        server_data = json.loads(read_text(SERVER_JSON))
        if server_data.get("version") != version:
            add_error(errors, f"server.json version {server_data.get('version')!r} does not match {version!r}")
        for package in server_data.get("packages", []):
            if package.get("version") != version:
                add_error(errors, "server.json package version does not match %s" % version)

    if WRAPPER_PACKAGE_JSON.exists():
        package_data = json.loads(read_text(WRAPPER_PACKAGE_JSON))
        if package_data.get("version") != version:
            add_error(errors, "stdio-wrapper package.json version does not match %s" % version)

    if errors:
        raise SystemExit("Version validation failed:\n- " + "\n- ".join(errors))


def is_forbidden_path(path: pathlib.Path) -> bool:
    if path.is_symlink():
        return True
    relative = path.relative_to(ROOT)
    if path.name in FORBIDDEN_NAMES:
        return True
    return any(part in FORBIDDEN_PARTS for part in relative.parts)


def collect_package_files() -> list[pathlib.Path]:
    files: list[pathlib.Path] = []
    for name in sorted(ALLOWED_ROOT_FILES):
        path = ROOT / name
        if path.exists():
            files.append(path)

    addon_path = ROOT / ADDON_ROOT
    for path in sorted(addon_path.rglob("*")):
        if path.is_file() and not is_forbidden_path(path):
            files.append(path)
    return files


def validate_package_member(name: str) -> str | None:
    if name.startswith("/") or "\\" in name:
        return f"Invalid zip member path: {name}"
    parts = pathlib.PurePosixPath(name).parts
    if ".." in parts:
        return f"Zip member escapes package root: {name}"
    if pathlib.PurePosixPath(name).name in FORBIDDEN_NAMES:
        return f"Forbidden file in package: {name}"
    if any(part in FORBIDDEN_PARTS for part in parts):
        return f"Forbidden directory in package: {name}"
    if name in ALLOWED_ROOT_FILES:
        return None
    if name.startswith(ADDON_ROOT + "/"):
        return None
    return f"Package member is outside allowed roots: {name}"


def validate_zip(path: pathlib.Path) -> None:
    errors: list[str] = []
    with zipfile.ZipFile(path, "r") as archive:
        infos = [info for info in archive.infolist() if not info.is_dir()]
        names = [info.filename for info in infos]
        for info in infos:
            error = validate_package_member(info.filename)
            if error:
                errors.append(error)
            mode = (info.external_attr >> 16) & 0o777777
            if stat.S_ISLNK(mode):
                errors.append(f"Symlink is not allowed in package: {info.filename}")
        required = f"{ADDON_ROOT}/plugin.cfg"
        if required not in names:
            errors.append(f"Package is missing {required}")
    if errors:
        raise SystemExit("Package validation failed:\n- " + "\n- ".join(errors))


def write_zip(files: list[pathlib.Path], output_path: pathlib.Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in files:
            relative = path.relative_to(ROOT).as_posix()
            error = validate_package_member(relative)
            if error:
                raise SystemExit(error)
            archive.write(path, relative)


def extract_release_notes(version: str) -> str:
    if not CHANGELOG.exists():
        return f"# v{version}\n\nSee CHANGELOG.md for details.\n"

    text = read_text(CHANGELOG)
    pattern = re.compile(
        rf"^## \[{re.escape(version)}\].*?\n(?P<body>.*?)(?=^## \[|\Z)",
        re.M | re.S,
    )
    match = pattern.search(text)
    if not match:
        return f"# v{version}\n\nSee CHANGELOG.md for details.\n"
    body = match.group("body").strip()
    return f"# v{version}\n\n{body}\n"


def read_wrapper_metadata(version: str) -> dict:
    if not WRAPPER_PACKAGE_JSON.exists():
        return {}
    data = json.loads(read_text(WRAPPER_PACKAGE_JSON))
    return {
        "package": data.get("name", ""),
        "version": data.get("version", version),
        "command": next(iter(data.get("bin", {"funplay-godot-mcp": ""}).keys())),
        "mcpName": data.get("mcpName", ""),
    }


def build_manifest(version: str, package_path: pathlib.Path, server_json_path: pathlib.Path | None) -> dict:
    tag = f"v{version}"
    package_sha = sha256_file(package_path)
    manifest = {
        "version": version,
        "tag": tag,
        "createdAt": dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "repository": {
            "url": REPOSITORY_URL,
            "source": "github",
        },
        "githubReleaseUrl": f"{REPOSITORY_URL}/releases/tag/{tag}",
        "godotAddon": {
            "file": package_path.name,
            "sha256": package_sha,
            "size": package_path.stat().st_size,
            "installRoot": ADDON_ROOT,
            "allowedRoots": [ADDON_ROOT, *sorted(ALLOWED_ROOT_FILES)],
        },
        "stdioWrapper": read_wrapper_metadata(version),
    }
    if server_json_path != None:
        manifest["mcpRegistry"] = {
            "serverJson": server_json_path.name,
            "serverName": "io.github.FunplayAI/funplay-godot-mcp",
            "sha256": sha256_file(server_json_path),
        }
    return manifest


def write_sha256s(paths: list[pathlib.Path], output_path: pathlib.Path) -> None:
    lines = [f"{sha256_file(path)}  {path.name}" for path in paths]
    output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def build_release(version: str, output_dir: pathlib.Path) -> pathlib.Path:
    validate_version(version)
    release_dir = output_dir / f"v{version}"
    if release_dir.exists():
        shutil.rmtree(release_dir)
    release_dir.mkdir(parents=True)

    package_path = release_dir / f"{PACKAGE_PREFIX}.v{version}.zip"
    write_zip(collect_package_files(), package_path)
    validate_zip(package_path)

    server_json_copy: pathlib.Path | None = None
    if SERVER_JSON.exists():
        server_json_copy = release_dir / "server.json"
        shutil.copyfile(SERVER_JSON, server_json_copy)

    notes_path = release_dir / "release-notes.md"
    notes_path.write_text(extract_release_notes(version), encoding="utf-8")

    manifest_path = release_dir / "release-manifest.json"
    manifest = build_manifest(version, package_path, server_json_copy)
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    sha_paths = [package_path, manifest_path, notes_path]
    if server_json_copy != None:
        sha_paths.append(server_json_copy)
    write_sha256s(sha_paths, release_dir / "SHA256SUMS.txt")

    return release_dir


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", default=read_plugin_version(), help="Release version, with or without leading v")
    parser.add_argument("--output-dir", default="dist", help="Directory for release artifacts")
    parser.add_argument("--verify-zip", help="Validate an existing release zip and exit")
    args = parser.parse_args()

    if args.verify_zip:
        validate_zip(pathlib.Path(args.verify_zip))
        print("Package validation passed.")
        return 0

    version = normalize_version(args.version)
    release_dir = build_release(version, ROOT / args.output_dir)
    print(f"Release artifacts written to {release_dir.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
