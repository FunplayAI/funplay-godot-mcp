import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { createServer } from "node:http";
import { once } from "node:events";
import { createInterface } from "node:readline";
import test from "node:test";

const wrapper = new URL("../bin/funplay-godot-mcp.js", import.meta.url);

test("a stalled request releases the serial queue", { concurrency: true }, async (parent) => {
  await Promise.all(["headers", "body"].map((stage) => parent.test(stage, { timeout: 65_000 }, async (context) => {
    const requests = [];
    const server = createServer(async (request, response) => {
      const chunks = [];
      for await (const chunk of request) {
        chunks.push(chunk);
      }
      const message = JSON.parse(Buffer.concat(chunks).toString());
      requests.push(message);
      assert.equal(request.headers["x-funplay-mcp-token"], "integration-token");
      if (message.id === 1) {
        if (stage === "body") {
          response.writeHead(200, { "content-type": "application/json" });
          response.write('{"jsonrpc":"2.0"');
        }
        return;
      }
      response.writeHead(200, { "content-type": "application/json" });
      response.end(JSON.stringify({ jsonrpc: "2.0", id: message.id, result: "ok" }));
    });
    server.listen(0, "127.0.0.1");
    await once(server, "listening");
    context.after(() => {
      server.closeAllConnections();
      server.close();
    });

    const child = spawn(process.execPath, [wrapper.pathname, "--url", `http://127.0.0.1:${server.address().port}/`, "--token", "integration-token"]);
    context.after(() => child.kill());
    const output = createInterface({ input: child.stdout });
    context.after(() => output.close());
    child.stdin.write('{"jsonrpc":"2.0","id":1,"method":"initialize"}\n');
    child.stdin.write('{"jsonrpc":"2.0","id":2,"method":"tools/list"}\n');

    const responses = [];
    for await (const line of output) {
      responses.push(JSON.parse(line));
      if (responses.length === 2) {
        break;
      }
    }
    assert.equal(responses[0].id, 1);
    assert.equal(responses[0].error.code, -32000);
    assert.match(responses[0].error.message, /timeout|aborted/i);
    assert.deepEqual(responses[1], { jsonrpc: "2.0", id: 2, result: "ok" });
    assert.deepEqual(requests.map((request) => request.id), [1, 2]);
  })));
});
