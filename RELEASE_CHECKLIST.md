# Release Checklist

Use this checklist before publishing a new open-source release of Funplay MCP for Godot.

## 1. Repository Hygiene

- [ ] `git status` is clean except for the files intended for the release
- [ ] No local junk is present (`.DS_Store`, temporary exports, local test files)
- [ ] `addons/funplay_mcp/plugin.cfg` version matches the intended release
- [ ] `addons/funplay_mcp/core/funplay_mcp_server.gd` `SERVER_VERSION` matches the intended release
- [ ] `server.json` and `stdio-wrapper/package.json` versions match the intended release
- [ ] `CHANGELOG.md` includes the release notes for the target version
- [ ] `README.md` and `README_CN.md` match the current product behavior
- [ ] `python scripts/validate_repo.py` passes locally
- [ ] `python scripts/package_release.py --version <version>` builds release artifacts locally

## 2. Godot Smoke Test

- [ ] Test in a clean Godot `4.2+` project
- [ ] Install from `dist/v<version>/Funplay.GodotMcp.v<version>.zip`
- [ ] Enable the plugin successfully
- [ ] Start the MCP server successfully
- [ ] Confirm the configured local endpoint is reachable from an MCP client
- [ ] If port `8765` is occupied, verify the server picks a free port and writes it to `user://funplay_mcp_settings.cfg`
- [ ] Click `Check Updates` in the dock and verify it either reports up to date or opens the GitHub Release page
- [ ] Run a read-only tool such as `get_scene_info`
- [ ] Run a scene-changing tool such as `create_node`
- [ ] Verify interaction logs appear in the `Funplay MCP` dock
- [ ] If scripts were touched, run `validate_gdscript_file` or `get_script_errors`

## 3. MCP Client Verification

- [ ] Verify at least one primary client can connect (`Claude Code`, `Cursor`, `Codex`, etc.)
- [ ] Confirm `tools/list` returns the expected tool set
- [ ] Confirm a tool call succeeds end-to-end from the external client
- [ ] Verify the one-click config output still matches the documented config snippets
- [ ] If testing stdio, run `node stdio-wrapper/bin/funplay-godot-mcp.js --url <endpoint>` and verify a JSON-RPC request is bridged

## 4. Docs and API Surface

- [ ] Built-in tool names in the README match exported tool names
- [ ] Any newly added tool is documented when user-visible
- [ ] Any user-visible behavior change is documented

## 5. GitHub Release Readiness

- [ ] `.github/workflows/ci.yml` passes
- [ ] `.github/workflows/release.yml` has the expected tag trigger and `contents: write` permission
- [ ] Release artifacts contain only allowed roots: `addons/funplay_mcp/**`, docs, license, changelog, and `server.json`
- [ ] `release-manifest.json` and `SHA256SUMS.txt` are present in `dist/v<version>/`
- [ ] PR checklist still reflects the current release process
- [ ] License file is present and correct
- [ ] Repository description/topics are set on GitHub
- [ ] Initial tags or release tags follow the chosen versioning scheme

## 6. Publish

- [ ] Commit the release changes with a clear release-oriented message
- [ ] Create and push the release tag
- [ ] Confirm the tag workflow created or updated the GitHub Release
- [ ] Confirm the GitHub Release contains `Funplay.GodotMcp.v<version>.zip`, `release-manifest.json`, `SHA256SUMS.txt`, `server.json`, and `release-notes.md`
- [ ] Verify the public repository renders the README correctly
- [ ] If publishing the stdio wrapper, publish `stdio-wrapper/` to npm before submitting `server.json` to the MCP Registry

## 7. Post-Release

- [ ] Re-test installation from the public Git URL or addon copy path
- [ ] Re-test installation from the GitHub Release zip
- [ ] Check the GitHub release page for broken links or formatting issues
- [ ] If `server.json` was published to the MCP Registry, verify the expected version appears in the registry API
- [ ] Announce the release where appropriate
