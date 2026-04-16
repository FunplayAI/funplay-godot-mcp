# Release Checklist

Use this checklist before publishing a new open-source release of Funplay MCP for Godot.

## 1. Repository Hygiene

- [ ] `git status` is clean except for the files intended for the release
- [ ] No local junk is present (`.DS_Store`, temporary exports, local test files)
- [ ] `addons/funplay_mcp/plugin.cfg` version matches the intended release
- [ ] `CHANGELOG.md` includes the release notes for the target version
- [ ] `README.md` and `README_CN.md` match the current product behavior

## 2. Godot Smoke Test

- [ ] Test in a clean Godot `4.2+` project
- [ ] Enable the plugin successfully
- [ ] Start the MCP server successfully
- [ ] Confirm the configured local endpoint is reachable from an MCP client
- [ ] If port `8765` is occupied, verify the server picks a free port and writes it to `user://funplay_mcp_settings.cfg`
- [ ] Run a read-only tool such as `get_scene_info`
- [ ] Run a scene-changing tool such as `create_node`
- [ ] Verify interaction logs appear in the `Funplay MCP` dock
- [ ] If scripts were touched, run `validate_gdscript_file` or `get_script_errors`

## 3. MCP Client Verification

- [ ] Verify at least one primary client can connect (`Claude Code`, `Cursor`, `Codex`, etc.)
- [ ] Confirm `tools/list` returns the expected tool set
- [ ] Confirm a tool call succeeds end-to-end from the external client
- [ ] Verify the one-click config output still matches the documented config snippets

## 4. Docs and API Surface

- [ ] Built-in tool names in the README match exported tool names
- [ ] Any newly added tool is documented when user-visible
- [ ] Any user-visible behavior change is documented

## 5. GitHub Release Readiness

- [ ] `.github/workflows/ci.yml` passes
- [ ] PR checklist still reflects the current release process
- [ ] License file is present and correct
- [ ] Repository description/topics are set on GitHub
- [ ] Initial tags or release tags follow the chosen versioning scheme

## 6. Publish

- [ ] Commit the release changes with a clear release-oriented message
- [ ] Create and push the release tag
- [ ] Create the GitHub Release notes
- [ ] Verify the public repository renders the README correctly

## 7. Post-Release

- [ ] Re-test installation from the public Git URL or addon copy path
- [ ] Check the GitHub release page for broken links or formatting issues
- [ ] Announce the release where appropriate
