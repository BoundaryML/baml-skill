---
name: core
description: Compact BAML skill (the baml_language rewrite). Load when working in .baml files. BAML is a statically-typed, expression-oriented language with first-class LLM functions — TypeScript with snake_case methods, `name type` class fields, and a `client:`/`prompt:` DSL. This skill covers the syntax and the traps; for EVERY stdlib name, method, or signature, run `baml describe` — never guess.
---

# baml

BAML is a **statically-typed, expression-oriented language with first-class LLM functions**. Think TypeScript with consistent twists: methods/stdlib are `snake_case`, the last expression in a block is its value, class fields are `name type` (no colon). A function with `client:` + `prompt:` is an LLM call that desugars into an ordinary function.

**Doctrine: this skill teaches syntax, not the stdlib. Before calling ANY method or stdlib helper, verify it with `baml describe`** — `baml describe Array` / `String` / `Map` / `Int` / `Float` for methods, `baml describe baml.json` (or any module) for helpers, `baml describe baml.errors` for typed errors. Guessed names are the #1 failure mode.

## Install + the agent loop

```bash
brew tap boundaryml/baml && brew install baml   # binary is `baml-cli` (alias to `baml`)

baml init                       # new project (writes baml.toml + baml_src/)
baml run --list                 # compile + list callable functions
baml run -e 'add(2, 3)'         # quick eval (recompiles everything — doubles as a syntax check)
baml describe <name>            # THE reference: modules, types, methods, signatures, docs
baml test --list                # list testsets::cases
baml test -i "suite::case"      # run one case
baml fmt baml_src/main.baml     # formatter — run before finishing
```

No `import` statements — the CLI loads every `.baml` file under the project root (conventionally `baml_src/`). Namespaces are opt-in via `ns_<name>/` directories; symbols resolve by short name or full path (`baml.env.get_or_panic` ≡ `env.get_or_panic`).

## The language, by example

```baml
type UserId = string;                       // top-level alias ends with ;
let x = 1;  x += 1;                         // let + reassignment; compound ops work

function add(a: int, b: int) -> int { a + b }     // trailing expression IS the return value
function abs(x: int) -> int {
  if (x < 0) { return -x; };                // early return: `return` + trailing `;`
  x
}

class Point {
  x int                                     // fields are `name type` — NO colon, NO comma
  y int
  function new(x: int, y: int) -> Point { Point { x: x, y: y } }   // construction DOES use `:`
  function norm2(self) -> int { self.x * self.x + self.y * self.y } // methods take explicit `self`
}
enum Color { Red, Green, Blue }             // refer to as Color.Red
class Box<T> { value T  function of(v: T) -> Box<T> { Box<T> { value: v } } }

function flow(xs: int[]) -> string {
  let sum = 0;
  for (let v in xs) {                       // for-in REQUIRES let; iterates VALUES (TS for...of)
    if (v < 0) { continue; };               // statement-style if ends with ;
    sum += v;
  }
  while (sum > 100) { sum /= 2; }
  match (sum) {                             // match/if/blocks are EXPRESSIONS
    0 => "zero",
    1 | 2 | 3 => "small",
    _ => "n=" + baml.unstable.string(sum),  // no implicit string coercion — stringify explicitly
  }
}

function opt(u: User?, cb: ((x: int) -> int)?) -> string {
  let r = cb?.(42);                         // ?. ?.[i] ?.() chain; ?? coalesces
  u?.name ?? "Anonymous"
}

class BadInput { message string }
function safe(v: string) -> string {
  parse(v) catch (e) { BadInput => "untitled" }   // catch arms are TYPE-ONLY: `T =>` / `_ =>`
}
// `throws T` is part of a signature; `catch` is non-exhaustive (unmatched types rethrow);
// `catch_all` must cover everything. Panics (index OOB, missing map key) are NOT catchable
// — prefer .at(i)/.get(k) (return T?) over xs[0]/m[k].
```

Primitives `int float bool string null unknown`; composites `T[]  map<string, V>  T?  A | B`, literal types `"open" | "closed"`, function types `(x: int) -> int`. `json` = the usual recursive union. Map keys MUST be `string`. `.filter` returns an Iterator — finish with `.collect()`. Empty `[]` infers its type on first push.

## The DSL — LLM functions

```baml
client<llm> Fast {
  provider openai
  options { model "gpt-4o-mini"  api_key env.OPENAI_API_KEY }   // options: whitespace-separated, NO colons/commas
}

class Intent { kind "billing" | "support" | "other"  confidence float }

function classify(text: string) -> Intent {
  client: Fast                              // or shorthand: client: "openai/gpt-4o-mini"
  prompt: #"
    Classify: {{ text }}
    {{ ctx.output_format }}                 {# ALWAYS include — injects the schema #}
  "#
}
```

The return type is the schema — declare a typed class and let BAML validate/retry. Prompts are `#"..."#` block strings with Jinja inside `{{ }}`/`{% %}`. Each LLM function also gets companions (`classify$parse(raw)`, `$render_prompt`, `$build_request`, `$stream`). Compose pipelines as plain functions calling typed stages.

## Tests

```baml
testset "intent" {
  test "parses a captured reply" {
    let r = baml.json.from_string<Intent>(#"{ "kind": "support", "confidence": 0.9 }"#);
    assert.equal(r.kind, "support");        // asserts: equal is_true not_null contains — that's all
  }
}
```

Run `baml test -i "intent::*"`. Feed stages cached JSON via `baml.json.from_string<T>(...)` — deterministic, no tokens.

## Traps for TS muscle memory

- `for (let x in xs)` iterates **values**; `for` always requires `let`.
- Last expression returns; a trailing `;` discards the value. Functions returning nothing: `-> null` with trailing `null`.
- Class fields `name type`; colons only in params, `let`, map literals, construction, match bindings.
- `"n=" + 5` does not compile — `baml.unstable.string(5)`. Only widening: `int + float -> float`.
- Indexing panics out of bounds — `.at(i)` / `.get(k)` return `T?`.
- Multiline strings are `#"..."#`; `client<llm>` options are whitespace-separated.
- `.length()` on strings counts codepoints.

**Everything else — every method list, every module, every signature: `baml describe <name>`. Do not invent stdlib names.**
