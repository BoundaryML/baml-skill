---
name: serving
description: Building HTTP servers and long-lived processes around BAML. Load when asked to "build an HTTP server in BAML", expose BAML functions as an API, or run BAML inside a daemon/worker. BAML's stdlib HTTP is client-only (fetch/send/fetch_sse — no listener), so the host owns the socket and BAML owns the typed request logic; this skill gives the verified two-file pattern.
---

# Serving — HTTP servers & long-lived processes

**BAML has no server primitive.** `baml describe baml.http` shows `fetch`,
`send`, `fetch_sse` and the `Request`/`Response`/`SseStream` classes — all
client-side. Don't search for a listener; split the work:

- **Host (Python etc.)** owns the socket, the loop, concurrency.
- **BAML** owns routing/domain logic as one typed, testable handler function.

## 1. The typed handler (BAML)

```baml
class HttpReq  { method string  path string  body string? }
class HttpResp { status int  body string }

function handle(req: HttpReq) -> HttpResp {
  match (req.path) {
    "/health" => HttpResp { status: 200, body: "ok" },
    "/greet"  => HttpResp { status: 200,
                            body: baml.json.stringify(greet(req.body ?? "world").to_json()) },
    _         => HttpResp { status: 404, body: "not found" },
  }
}
```

Keep the handler's own fields plain (`string`/`int`) — see the bridges skill's
caveat: enum / literal-union fields currently break `--output-format json` and
`.to_json()`. Test it before wiring the host:

```bash
baml run --function handle --output-format json -- handle \
  --json-args '{"req":{"method":"GET","path":"/greet","body":"ana"}}'
# {"status":200,"body":"{\"name\":\"ana\",\"message\":\"hi ana\"}"}
```

## 2. The host loop (Python, zero dependencies)

Verified end-to-end with `python3 serve.py` + curl:

```python
import json, subprocess
from http.server import BaseHTTPRequestHandler, HTTPServer

def call_baml(fn, args):
    out = subprocess.run(
        ["baml", "run", "--function", fn, "--output-format", "json",
         "--", fn, "--json-args", json.dumps(args)],
        capture_output=True, text=True, check=True)
    return json.loads(out.stdout)

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        resp = call_baml("handle", {"req": {"method": "GET", "path": self.path, "body": None}})
        self.send_response(resp["status"])
        self.end_headers()
        self.wfile.write(resp["body"].encode())

HTTPServer(("127.0.0.1", 8941), Handler).serve_forever()
```

The subprocess bridge recompiles the project per request — perfectly fine for
dev and demos. For production traffic, swap `call_baml` for the generated SDK
(same handler, no subprocess):

```python
from baml_sdk import handle           # after `baml generate`; see the bridges skill
resp = handle({"method": "GET", "path": self.path, "body": None})
```

(The SDK route requires `baml_core` version-matched to the CLI — nightly CLI →
`pip install --pre baml-core`. When that pin is awkward, stay on the subprocess
bridge; it has no Python dependency at all.)

## 3. Daemons / workers that LIVE in BAML

A long-running loop can be pure BAML when the host capability you need is just
shelling out, files, or outbound HTTP:

```baml
function worker() -> null {
  while (true) {
    let job = baml.http.fetch("http://queue.local/next");
    if (job.ok()) { process(job.text()); } else { baml.sys.sleep(1000); };
  }
  null
}
```

Run it with `baml run worker`. But the moment you need to **accept** sockets,
hold DB connections, or fan out concurrently, invert: host loop + BAML logic.
`for`/`while` are sequential — concurrency belongs to the host
(`asyncio.gather` over `*_async` SDK calls).

## Pattern summary

| Need | Shape |
|---|---|
| HTTP API over BAML logic | host server → subprocess bridge or SDK → `handle(HttpReq) -> HttpResp` |
| CLI tool | `baml run <fn>` auto-CLI, or `baml pack <fn>` for a standalone binary |
| Poller / consumer | pure-BAML `while` loop with `baml.http.fetch` + `baml.sys.sleep` |
| Concurrent pipeline | host `asyncio.gather` over generated `*_async` functions |
