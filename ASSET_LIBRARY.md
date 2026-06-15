# Godot Asset Library Release Notes

This project is designed to be publishable as a regular Godot addon.

## Positioning

- Native Godot editor plugin with an embedded HTTP MCP server.
- No Python daemon or external runtime is required for the Godot-side addon.
- Works from the `addons/funplay_mcp/` install root.
- MCP clients can connect directly over HTTP, or through the optional npm stdio wrapper when a client requires stdio.

## Package Contents

The Godot addon package should include:

- `addons/funplay_mcp/**`
- `README.md`
- `README_CN.md`
- `LICENSE`
- `CHANGELOG.md`
- `CONTRIBUTING.md`
- `ASSET_LIBRARY.md`
- `server.json`

The package must not include project-local Godot metadata, editor caches, export presets, build outputs, or dependency folders.

## Release Build

Build and validate the Asset Library package with:

```bash
python scripts/package_release.py --version <version>
python scripts/package_release.py --verify-zip dist/v<version>/Funplay.GodotMcp.v<version>.zip
```

The release builder validates that every zip member is either under `addons/funplay_mcp/` or in the explicit root-file allowlist.

## Asset Library Submission

Recommended submission metadata:

- Name: `Funplay MCP for Godot`
- Category: `Tools`
- License: `MIT`
- Godot version: `4.2+`
- Download URL: the GitHub Release zip for the target version
- Store thumbnail: use the generated store media assets, not a bundled addon icon file
- Support level: community/open-source GitHub issues

Submission notes should emphasize that the addon is Godot-native, ships as a normal editor plugin, and does not require a sidecar daemon for core workflows.

## Update Safety

Automatic update or installer flows must be designed around these rules before writing files:

- Verify release artifact checksums before unpacking.
- Dry-run the file list and report added, changed, skipped, and rejected paths.
- Allow writes only under `res://addons/funplay_mcp/` unless a future installer explicitly adds a narrower, reviewed exception.
- Reject absolute paths, parent-directory traversal, symlinks, hidden local metadata, and host project configuration writes.
- Keep manual install from the GitHub Release zip as the fallback when validation fails.

## Optional CC0 Asset Import Roadmap

External asset search/download should stay optional and user-initiated.

Recommended import contract:

- Search only approved CC0 or permissive-license sources after the user asks for network asset lookup.
- Capture source URL, license, author or pack name, checksum, and download time.
- Download under `res://assets/imported/<source>/<pack>/`.
- Never overwrite existing project files by default.
- Store attribution/license metadata next to imported files.
- Trigger a filesystem scan and return imported paths plus suggested usage steps.
