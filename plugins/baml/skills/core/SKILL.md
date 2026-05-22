---
name: core
description: Foundation knowledge for writing BAML. ALWAYS load this first when working in .baml files, when the user asks how to install / use BAML, or when answering any BAML question. Covers install, project layout with `ns_*` namespaces, the `baml run / describe / fmt / generate` agent loop, syntax essentials (classes with `: Type,` fields, snake_case functions, type aliases ending in `;`), stdlib (Collections/Strings, JSON via `baml.json.*`, files/HTTP/shell/env via `baml.fs/http/sys/env`), `match` + typed `throws / catch`, and common pitfalls. BAML is a general-purpose typed language with LLM-function support — not just a prompt DSL. Load the other baml:* skills only as the task demands.
---

# baml:core

Foundation for any BAML work. **BAML is a typed language for reliable LLM functions, structured output, and small orchestration programs.** It has functions, classes with methods, control flow, a stdlib, and the LLM-function pattern as one feature among many. Drop this skill the moment a task touches a `.baml` file.

Other skills to optionally load:

- `baml:llm-functions` — defining `function X(...) -> T { client: Y  prompt #"..."# }`
- `baml:pipelines` — composing typed LLM stages; routing via `match`
- `baml:testing` — `testset` / `test` blocks + `assert.*`
- `baml:bridges` — `baml generate` + the Python `baml_sdk` client; host bridges

## 1. Install

```bash
brew tap boundaryml/baml
brew install baml
```

The binary currently installs as `baml-cli`; `which baml` may return nothing on day one. Use `which baml-cli` if needed.

For a per-Python-project dependency: `uv add baml_core`.

VS Code extension VSIX: https://drive.google.com/drive/folders/1M6KJzWd2Ee1vcvGjY_Gkbm7GXUWlylzJ — then `code --install-extension <path>.vsix`.

## 2. Project shape

BAML has no `import` statements. The CLI loads every `.baml` file under the project root (or `--from` directory).

```
my-app/
├── baml.toml
└── baml_src/
    ├── main.baml
    ├── types.baml
    ├── clients.baml
    └── ns_eval/
        └── metrics.baml
```

Namespaces come from `ns_<name>` directories. Plain folders are only organization. Same-namespace symbols are bare; cross-namespace symbols use `root.eval.Score`. `root` means "this project's root namespace" — not the standard library and not an import alias. Stdlib uses `baml.*`, `assert.*`, and `log.*`.

```baml
// baml_src/types.baml — root namespace
class Config {
  model: string,
}

// baml_src/ns_eval/metrics.baml — namespace root.eval
class Score {
  passed: bool,
  reason: string,
}

function judge(config: root.Config, output: string) -> Score {
  Score {
    passed: output.length() > 0,
    reason: "checked with " + config.model,
  }
}
```

## 3. The agent loop

```bash
baml run --list                          # compile + list callable functions
baml describe --symbols                  # list project symbols
baml describe baml.json                  # JSON helpers under baml.json (modules work)
baml describe String                     # method list for the String class
baml test --list
baml test -i "suite::case"               # run one case
baml run --function main --json-args @args.json --output json
baml run -e 'some_helper("sample")'      # quick eval; recompiles whole project
baml fmt baml_src/main.baml              # format in place
baml generate                            # regenerate host-language client code
```

Rules:

- Run `baml describe` instead of inventing stdlib names. Module dotted paths (`baml.json`, `baml.fs`) and top-level classes (`Array`, `Map`, `Int`, `Float`, `Bool`) are valid arguments — `describe baml.json` prints every helper under that namespace.
- The standard library is basically like TypeScript, but module-level functions use `snake_case`.
- Keep the entire project compiling — `run -e` still compiles all `.baml` files. Use it as a syntax check.
- Use `--json-args` for classes, arrays, maps, optionals, unions, and nested input.
- Use `--output json` when a host program reads BAML output.
- Format touched `.baml` files before finishing.
- Run `baml generate` after changing functions/types that application code imports.

## 4. Syntax essentials

Write **formatted** BAML. The parser may accept looser punctuation, but agents should emit canonical code.

```baml
type UserId = string;
type Metadata = map<string, json>;

enum Priority {
  Low,
  Medium,
  High,
}

class Ticket {
  id: UserId,
  title: string,
  priority: Priority,
  tags: string[],
  metadata: Metadata?,

  function new(id: UserId, title: string) -> Ticket {
    Ticket { id: id, title: title.trim(), priority: Priority.Medium, tags: [], metadata: null }
  }

  function label(self) -> string {
    self.id + ": " + self.title
  }
}

function add(a: int, b: int) -> int {
  a + b
}

function abs(x: int) -> int {
  if (x < 0) { return -x; };
  x
}
```

Rules:

- **Top-level type aliases end with `;`** (`type UserId = string;`).
- Prefer **`snake_case`** for user-defined functions, parameters, and locals.
- **Class names** and **`client<llm>` names**: `UpperCamelCase`.
- **Class fields**: `name: Type,` — colon between name and type, **comma after each field**.
- Function parameters and `let` annotations: `name: Type`.
- Object constructors and maps: `key: value`.
- Class methods take explicit `self`; factories (`new`) are ordinary methods without `self`.
- Last expression in a block is the return value. A trailing `;` discards the value.
- Functions that return nothing declare `-> void` (not `-> null`). Use `return;` for early exit.
- **`for` headers require `let`**: `for (let item in items) { ... }`. The `for` block has no trailing `;`. A **statement-style `if`** inside the loop does need `;`.
- `match (x) { ... }` — parens around the scrutinee.

Common types: `int`, `float`, `bool`, `string`, `null`, `void`, `unknown`, `never`, `json`, `uint8array`, `Ticket[]`, `map<string, int>`, `Ticket?`, `Ticket | string | null`, `"open" | "closed"`, `1 | 2 | 3`.

Use `json` for arbitrary valid JSON — it's a structural alias for `null | bool | int | float | string | json[] | map<string, json>`. Use `unknown` only when the value may be any BAML value, including non-JSON runtime values. No broad implicit coercion: `int + float -> float`, but `int`, `float`, `bool`, `string` are distinct types. Convert with `baml.unstable.string(value)` when building display text.

## 5. Collections and strings

```baml
function normalize(raw: string) -> string {
  let normalized = raw.trim().replace_all("\r", "").replace_all("\t", " ");

  while (normalized.includes("  ")) {
    normalized = normalized.replace_all("  ", " ");
  }

  normalized
}

function tag_summary(tags: string[]) -> string {
  let clean: string[] = [];

  for (let tag in tags) {
    let value = normalize(tag).to_lower_case();
    if (value.length() > 0) {
      clean.push(value);
    };
  }

  clean.join(", ")
}

function count_by_priority(tickets: Ticket[]) -> map<string, int> {
  let counts: map<string, int> = {};
  counts.set("high", 0);
  counts.set("other", 0);

  for (let t in tickets) {
    if (t.priority == Priority.High) {
      counts.set("high", (counts.get("high") ?? 0) + 1);
    } else {
      counts.set("other", (counts.get("other") ?? 0) + 1);
    };
  }

  counts
}
```

- Instance methods on `string`, `Array`, and `Map` are **snake_case**: `.to_lower_case()`, `.to_upper_case()`, `.replace_all()`, `.replace()`, `.trim()`, `.includes()`, `.starts_with()`, `.ends_with()`, `.index_of()`, `.char_at()`, `.matches()`, `.split()`, `.substring()`, `.length()`, `.push()`, `.join()`, `.at()`, `.set()`, `.get()`, `.has()`.
- Module functions under `baml.*` are also **snake_case**: `baml.json.from_string`, `baml.fs.read`, `baml.env.get_or_panic`.
- Prefer `array.at(i)` and `map.get(key)` (return `T?`) when absence is normal. Direct indexing (`emails[0]`) panics on OOB.
- Don't assume regex, numeric parsing, byte length, UUID, base64, crypto, or date/time helpers exist — check `baml describe`.

## 6. JSON

```baml
class Email { id: string, from: string, subject: string, body: string, }

function load_emails(raw: string) -> Email[] {
  baml.json.from_string<Email[]>(raw)
}

function encode_emails(emails: Email[]) -> string {
  baml.json.stringify_pretty(emails.to_json())
}

function read_optional_string(obj: map<string, json>, key: string) -> string? {
  let value = obj.get(key) ?? null;

  match (value) {
    let s: string => s,
    _ => null,
  }
}
```

Canonical helpers under `baml.json` (run `baml describe baml.json` for the live list):

- `from_string<T>(s: string) -> T` — decode a string straight into `T`.
- `from_json<T>(j: json) -> T` — decode a `json` value into `T`, honoring user-defined `from_json` overrides.
- `parse(s: string) -> json` — parse a string to an untyped `json` value.
- `stringify(j: json) -> string` / `stringify_pretty(j: json) -> string` — encode `json` back to a string.
- `to_string<T>(v: T) -> string` — encode any BAML value to its JSON string.
- `to_json<T>(v: T) -> json` — encode any BAML value to its `json` representation.

Serialization:

- On a **concretely typed** value, call **`value.to_json()`** to get `json`. Runtime dispatch matches `baml.json.to_json(value)`, including user-defined `to_json` overrides on classes.
- Prefer **`baml.json.to_json<T>(v)`** when `v` is typed as a type parameter or otherwise abstract `T` — helpers that walk generic containers, for example.
- Some values are not JSON-serializable (function-like values, etc.); serialization can throw `baml.json.JsonSerializationError`.

Keep wire data as `json` at the boundary, then narrow with `from_json` (or `parse` + `from_json`) before domain logic.

## 7. Files, HTTP, shell, env

```baml
function read_text(path: string) -> string {
  baml.fs.read(path)
}

function write_report(path: string, results: Ticket[]) -> int {
  baml.fs.write(path, baml.json.stringify_pretty(results.to_json()))
}

function fetch_json(url: string) -> json {
  let res = baml.http.fetch(url);

  if (!res.ok()) {
    throw "HTTP " + baml.unstable.string(res.status_code);
  };

  baml.json.parse(res.text())
}

function required_key(name: string) -> string {
  baml.env.get_or_panic(name)
}

function run_script(cmd: string) -> string {
  let out = baml.sys.shell(cmd, null);
  out.stdout.to_string()
}
```

- `baml.http.fetch(url) -> Response` — Response has `.ok()`, `.status_code`, `.text()`, `.bytes()`.
- `baml.env.get(name) -> string?` (silent miss) or `baml.env.get_or_panic(name) -> string` (panics if absent). There is no `baml.sys.env` — that name does not resolve.
- `baml.sys.shell(cmd, options?) -> ShellOutput` — ShellOutput has `.stdout: uint8array`, `.stderr: uint8array`, `.exit_code: int`, and `.ok()`. Decode bytes with `.to_string()`. Other `baml.sys.*` helpers: `exec`, `sleep`, `panic`, `now_ms`, `argv`.

Use `baml.sys.shell` sparingly — repeated shell calls dominate runtime and make tests brittle. Prefer one structured bridge call over many tiny shell calls. See `baml:bridges`.

## 8. Match and errors

```baml
function priority_weight(p: Priority) -> int {
  match (p) {
    Priority.Low => 1,
    Priority.Medium => 2,
    Priority.High => 3,
  }
}

function json_summary(value: json) -> string {
  match (value) {
    null => "null",
    let text: string => "string:" + text,
    let n: int => "int:" + baml.unstable.string(n),
    let items: json[] => "array:" + baml.unstable.string(items.length()),
    let obj: map<string, json> => "object:" + baml.unstable.string(obj.length()),
    _ => "other",
  }
}
```

`let <name>: <Type> =>` binds the narrowed value. `_: <Type> =>` matches without binding. `_` is the wildcard.

```baml
class BadInput { message: string, }

function require_non_empty(value: string) -> string throws BadInput {
  let trimmed = value.trim();
  if (trimmed.length() == 0) {
    throw BadInput { message: "expected non-empty string" };
  };
  trimmed
}

function safe_title(value: string) -> string {
  require_non_empty(value) catch (e) {
    BadInput => "untitled",
  }
}
```

`catch` is an **expression** — each arm must produce a type compatible with the success path. Unhandled throw types continue upward. `throws T` is part of the function signature and is visible to callers, but the compiler does **not** enforce that callers catch or re-throw it — a caller that ignores a declared throw will compile fine and produce a runtime panic ("uncaught throw") if the throw fires. You can throw any value (classes, strings, ints) but classes give callers a typed shape to match on.

Avoid panics for normal control flow. Prefer `map.get`, `array.at`, typed throws, and explicit null handling.

## 9. Common pitfalls

- **Forgetting `,` after class fields** — `class T { id: int, name: string, }`, not `id: int name: string`.
- **Forgetting `;` on type aliases** — `type UserId = string;`, not `type UserId = string`.
- **`function X(self, ...)`** for instance methods; factories like `new` take no `self`.
- **`for` block has no trailing `;`** — but a statement-style `if` inside it does.
- **`-> null` instead of `-> void`** — empty-return functions are `-> void`.
- **camelCase method names** like `toLowerCase`, `replaceAll`, `indexOf` — wrong. The current stdlib is snake_case: `to_lower_case`, `replace_all`, `index_of`. User-defined functions are also snake_case.
- **`baml.json.encode` / `decode_str`** — not the API. It's `parse`, `stringify`, `stringify_pretty`, `from_string`, `from_json`, `to_json`.
- **Inventing stdlib names** — run `baml describe baml.json` (or `String`, `Array`, `Map`) instead of guessing.
- **`length()` returns codepoints**, not bytes. There's no `to_bytes()` on `string` in the current stdlib; reach for a bridge if you need byte length.
- **No regex** in stdlib. Use `.split()`, `.replace_all()`, or a bridge.
- **`catch (e) { _: T => … }` pattern** — wrong. Catch arms are type-only: `catch (e) { T => value }` (or `_ => value` for the wildcard arm).
- **Direct indexing panics** — `array[0]` on an empty array crashes; prefer `.at(0)` which returns `T?`.

## 10. Design defaults

Prefer:
- Typed classes/enums/literal unions for LLM schemas (see `baml:llm-functions`).
- `json` and `baml.json.*` at external boundaries.
- `value.to_json()` for concretely typed → `json`; `baml.json.to_json<T>` for abstract `T`.
- `map.get`, `array.at`, and explicit null handling.
- Deterministic tests for parsing, validation, scoring (see `baml:testing`).
- `baml describe`, `baml run --list`, `baml test --list`, and `baml fmt` as the normal agent loop.

Avoid:
- Inventing stdlib helper names without `baml describe`.
- Hand-written JSON concatenation.
- Per-call shell-outs inside tight loops.
- Live LLM calls in deterministic CI tests.
- Free-form prompt contracts where typed output would work.
