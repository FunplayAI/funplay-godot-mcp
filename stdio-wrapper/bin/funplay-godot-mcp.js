#!/usr/bin/env node

import { argv, env, exit, stderr, stdin, stdout } from "node:process";

const VERSION = "0.9.0";
const DEFAULT_URL = "http://127.0.0.1:8765/";

const options = parseArgs(argv.slice(2));
if (options.help) {
  stdout.write(buildHelp());
  exit(0);
}
if (options.version) {
  stdout.write(`${VERSION}\n`);
  exit(0);
}

const endpoint = normalizeEndpoint(
  options.url || env.FUNPLAY_GODOT_MCP_URL || env.GODOT_MCP_URL || DEFAULT_URL,
);

let buffer = "";
let queue = Promise.resolve();

stdin.setEncoding("utf8");
stdin.on("data", (chunk) => {
  buffer += chunk;
  drainBuffer(false);
});

stdin.on("end", () => {
  drainBuffer(true);
});

stdin.on("error", (error) => {
  stderr.write(`[funplay-godot-mcp] stdin error: ${error.message}\n`);
});

function drainBuffer(flush) {
  while (true) {
    const index = buffer.indexOf("\n");
    if (index < 0) {
      break;
    }
    const line = buffer.slice(0, index);
    buffer = buffer.slice(index + 1);
    enqueueLine(line);
  }

  if (flush && buffer.trim() !== "") {
    enqueueLine(buffer);
    buffer = "";
  }
}

function enqueueLine(line) {
  queue = queue
    .then(() => handleLine(line))
    .catch((error) => {
      stderr.write(`[funplay-godot-mcp] bridge error: ${error.stack || error.message}\n`);
    });
}

async function handleLine(line) {
  const trimmed = line.trim();
  if (trimmed === "") {
    return;
  }

  let message;
  try {
    message = JSON.parse(trimmed);
  } catch {
    writeMessage({
      jsonrpc: "2.0",
      id: null,
      error: {
        code: -32700,
        message: "Parse error",
      },
    });
    return;
  }

  if (Array.isArray(message)) {
    const responses = [];
    for (const item of message) {
      const response = await forwardMessage(item);
      if (response !== null) {
        responses.push(response);
      }
    }
    if (responses.length > 0) {
      writeMessage(responses);
    }
    return;
  }

  const response = await forwardMessage(message);
  if (response !== null) {
    writeMessage(response);
  }
}

async function forwardMessage(message) {
  try {
    const response = await fetch(endpoint, {
      method: "POST",
      headers: {
        "accept": "application/json",
        "content-type": "application/json",
      },
      body: JSON.stringify(message),
    });

    if (response.status === 204) {
      return null;
    }

    const text = await response.text();
    if (text.trim() === "") {
      return buildErrorFor(message, -32603, `Godot MCP returned HTTP ${response.status} with an empty body`);
    }

    try {
      return JSON.parse(text);
    } catch {
      return buildErrorFor(message, -32603, `Godot MCP returned invalid JSON over HTTP ${response.status}`);
    }
  } catch (error) {
    return buildErrorFor(
      message,
      -32000,
      `Failed to reach Godot MCP at ${endpoint}: ${error.message}`,
    );
  }
}

function buildErrorFor(message, code, messageText) {
  if (!isJsonRpcRequest(message)) {
    stderr.write(`[funplay-godot-mcp] ${messageText}\n`);
    return null;
  }

  return {
    jsonrpc: "2.0",
    id: message.id,
    error: {
      code,
      message: messageText,
    },
  };
}

function isJsonRpcRequest(value) {
  return value !== null
    && typeof value === "object"
    && !Array.isArray(value)
    && Object.prototype.hasOwnProperty.call(value, "id");
}

function writeMessage(message) {
  stdout.write(`${JSON.stringify(message)}\n`);
}

function normalizeEndpoint(value) {
  const trimmed = String(value || "").trim();
  return trimmed === "" ? DEFAULT_URL : trimmed;
}

function parseArgs(args) {
  const parsed = {
    help: false,
    version: false,
    url: "",
  };

  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i];
    if (arg === "--help" || arg === "-h") {
      parsed.help = true;
    } else if (arg === "--version" || arg === "-v") {
      parsed.version = true;
    } else if (arg === "--url") {
      parsed.url = args[i + 1] || "";
      i += 1;
    } else if (arg.startsWith("--url=")) {
      parsed.url = arg.slice("--url=".length);
    } else {
      stderr.write(`[funplay-godot-mcp] Unknown argument ignored: ${arg}\n`);
    }
  }

  return parsed;
}

function buildHelp() {
  return `Funplay MCP for Godot stdio bridge ${VERSION}

Usage:
  funplay-godot-mcp [--url http://127.0.0.1:8765/]

Environment:
  FUNPLAY_GODOT_MCP_URL   Godot MCP HTTP endpoint
  GODOT_MCP_URL           Compatibility endpoint fallback

The Godot editor addon must be enabled and its MCP server must be running.
`;
}
