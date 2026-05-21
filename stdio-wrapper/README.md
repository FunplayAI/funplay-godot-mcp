# Funplay Godot MCP stdio wrapper

<!-- mcp-name: io.github.FunplayAI/funplay-godot-mcp -->

This package bridges MCP stdio clients to the local HTTP server started by the Funplay MCP for Godot editor addon.

## Usage

Start Godot, enable the addon, and make sure the Funplay MCP server is running. For local development, link the wrapper first:

```bash
npm link
```

Then run:

```bash
funplay-godot-mcp --url http://127.0.0.1:8765/
```

You can also configure the endpoint through an environment variable:

```bash
FUNPLAY_GODOT_MCP_URL=http://127.0.0.1:8765/ funplay-godot-mcp
```

## MCP client config

```json
{
  "mcpServers": {
    "funplay": {
      "command": "funplay-godot-mcp",
      "env": {
        "FUNPLAY_GODOT_MCP_URL": "http://127.0.0.1:8765/"
      }
    }
  }
}
```
