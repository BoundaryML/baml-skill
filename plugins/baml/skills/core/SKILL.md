---
name: core
description: Minimal BAML skill. BAML is a statically-typed, expression-oriented language with first-class LLM functions — TypeScript-like, snake_case methods. The CLI is the reference: run `baml describe` for every name and `baml run -e` to check everything. Never guess stdlib.
---

# baml — describe-first

BAML ≈ TypeScript, expression-oriented, snake_case methods, with LLM functions (`client:` + `prompt:` blocks that desugar to plain functions). **The CLI is the documentation. Discover, don't guess:**

```bash
brew tap boundaryml/baml && brew install baml   # binary: `baml-cli` (alias `baml`)

baml init                        # new project (baml.toml + baml_src/)
baml describe baml.json          # ← THE reference for any module/type/method/signature
baml describe Array              #   (Array, String, Map, Int, Float, baml.fs, baml.errors, ...)
baml run --list                  # compile + list functions
baml run -e 'expr'               # eval an expression — fast feedback, doubles as a syntax check
baml test --list && baml test -i "suite::case"
baml fmt baml_src/main.baml      # run before finishing
```

## The five fatal traps (everything else, `baml describe` it)

1. Class fields are `name type` — no colon, no comma. Construction uses `:` (`Point { x: 1 }`). Methods take explicit `self`; factories don't.
2. Last expression in a block is its value (Rust-style). Early exit: `return x;` with trailing `;`. No-value functions: `-> null` + trailing `null`.
3. `for (let x in xs)` iterates VALUES and requires `let`. `if`/`match`/blocks are expressions; `match (v) { 0 => "a", _ => "b" }`.
4. No implicit string coercion (`"n=" + 5` won't compile — `baml.unstable.string(5)`); indexing panics out of bounds (use `.at(i)`/`.get(k)` → `T?`); `.filter(...)` needs `.collect()`; map keys must be `string`.
5. `catch` arms are type-only and non-exhaustive: `f(x) catch (e) { BadInput => fallback }`; `throws T` is part of the signature; panics aren't catchable.

## LLM functions + tests, minimum viable

```baml
class Intent { kind "billing" | "support" | "other"  confidence float }

function classify(text: string) -> Intent {
  client: "openai/gpt-4o-mini"             // options blocks are whitespace-separated, no colons
  prompt: #"Classify: {{ text }}  {{ ctx.output_format }}"#   // ALWAYS include ctx.output_format
}

testset "intent" {
  test "parses" {
    let r = baml.json.from_string<Intent>(#"{ "kind": "support", "confidence": 0.9 }"#);
    assert.equal(r.kind, "support");       // asserts: equal is_true not_null contains
  }
}
```

The return type is the schema; prompts are `#"..."#` block strings with Jinja inside `{{ }}`. Every LLM function gets a `name$parse(raw)` companion for parsing captured replies in tests.

**Workflow: sketch → `baml run -e` constantly → `baml describe` anything unfamiliar → `baml test` → `baml fmt`.**
