# Contributing to Funplay MCP for Godot

Thanks for your interest in contributing! Here's how to get started.

## Development Setup

1. Open this repository directly in Godot `4.2+`, or copy `addons/funplay_mcp` into a clean Godot test project
2. Enable the plugin in **Project → Project Settings → Plugins**
3. Open the **Funplay MCP** dock
4. Start the server and confirm it is reachable at `http://127.0.0.1:8765/`
5. Verify at least one MCP client can connect

## Code Style

- GDScript with tabs or the prevailing file style already used in the repo
- Keep changes focused and engine-idiomatic
- Prefer small helper methods over deeply nested giant functions
- Comments in Chinese or English are both fine

## Adding a New Tool

1. Add the implementation to `addons/funplay_mcp/core/funplay_core_tools.gd`
2. Register the tool in `addons/funplay_mcp/core/funplay_tool_registry.gd`
3. If useful, expose related resources or prompts
4. Update `README.md` and `README_CN.md` for user-visible changes
5. Update `CHANGELOG.md` when the change affects users

## Validation

Before submitting a PR, please verify the change in a Godot test project:

1. Enable the plugin and start the MCP server
2. Confirm the MCP server starts successfully
3. Run at least one read-only workflow such as `get_scene_info`
4. If your change affects scene editing, run at least one write workflow such as `create_node`
5. If your change affects scripts, validate it with `validate_gdscript_file` or `get_script_errors`
6. If your change affects play mode, confirm the related workflow inside the Godot editor

## Repository Hygiene

- Do not commit local files such as `.DS_Store`, temp exports, or scratch files
- Keep PRs focused: one fix, feature, or cleanup per PR
- Avoid unrelated refactors in the same PR

## Documentation

- Update `README.md` for user-visible behavior changes
- Update `README_CN.md` when the English README changes materially
- Update `CHANGELOG.md` for changes that affect users or contributors

## Submitting a PR

1. Fork the repo and create a feature branch
2. Make and test your changes in Godot Editor
3. Run through the validation steps above
4. Submit a PR with a clear description of what changed and why

## License

By contributing, you agree that your contributions will be licensed under MIT.
