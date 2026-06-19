---
name: core
description: Minimal BAML skill. BAML is a statically-typed, expression-oriented language with first-class LLM functions — TypeScript-like, snake_case methods. The CLI is the reference: run `baml describe` for every name and `baml run -e` to check everything. Never guess stdlib.
---

# baml — describe-first

BAML ≈ TypeScript, expression-oriented, snake_case methods, with LLM functions (`client:` + `prompt:` blocks that desugar to plain functions). **The CLI is the documentation. Discover, don't guess:**

```bash
brew install baml                # binary: `baml-cli` (alias `baml`)

baml init                        # new project (baml.toml + baml_src/)
baml describe baml.json          # ← THE reference for any module/type/method/signature
baml describe Array              #   (Array, String, Map, Int, Float, baml.fs, baml.errors, ...)
                                 #   If output ends with "… N more lines", re-run with
                                 #   `--budget <higher-number>` to see the rest.
baml check                       # compile-check the project — errors + warnings
baml run -e 'expr'               # eval an expression — fast feedback, doubles as a syntax check
baml test --list && baml test -i "suite::case"
baml fmt baml_src/main.baml      # run before finishing
```

Pure (non-LLM) functions need no test block, testset wrapper, or client config — verify them instantly with `baml run -e 'add(2, 3)'`. This is the fastest feedback path for arithmetic, string-processing, and utility functions.

## The five fatal traps (everything else, `baml describe` it)

1. Class fields are `name: type,` — `baml fmt` writes the colon + comma (bare `name type` also parses, but fmt normalizes). Construction matches: `Point { x: 1 }`. Methods take explicit `self`; factories don't.
2. Last expression in a block is its value (Rust-style). Early exit: `return x;` with trailing `;`. No-value functions: `-> null` + trailing `null`.
3. `for (let x in xs)` iterates VALUES and requires `let`. `if`/`match`/blocks are expressions; `match (v) { 0 => "a", _ => "b" }`.
4. No implicit string coercion (`"n=" + 5` won't compile — `baml.unstable.string(5)`); indexing panics out of bounds (use `.at(i)`/`.get(k)` → `T?`); closures are `(x: T) -> R { ... }` (the `=>` arrow is match-only — `.filter`/`.map` return arrays directly, no `.collect()`); map keys must be `string`.
5. `catch` arms are type-only and non-exhaustive: `f(x) catch (e) { BadInput => fallback }`; callee `throws` propagate implicitly unless caught, so callers do not need to re-declare `throws T` unless they want static enforcement at their own signature boundary; runtime panics are catchable too, via fully-qualified arms (`expr catch (e) { baml.panics.DivisionByZero => fallback }`, likewise `baml.panics.IndexOutOfBounds`), and like any arm the match is selective — a non-matching arm re-propagates the panic. (When available, `int.try_parse(s) -> int | null` is the non-throwing alternative.)

### Gotchas (easy-to-miss silent pitfalls)

- **Closures:** outside obvious inference contexts, closures need typed params **and** an explicit return annotation: `(x: int) -> int { x + 1 }`.
- **`??` precedence:** `??` binds looser than `+`; `m.get(w) ?? 0 + 1` parses as `m.get(w) ?? (0 + 1)`. Use parentheses: `(m.get(w) ?? 0) + 1`.
- **In-place array writes:** mutate arrays with index assignment (`arr[i] = v`); there is no `Array.set` method.
- **`while` loops exist:** `while (cond) { ... }` is valid and works for imperative loops.
- **No `mut` keyword:** `let` bindings are reassignable by default, so `let mut i = 0` is a parse error.
- **`catch` type paths:** `catch` arms must use fully-qualified error names (for example `baml.json.JsonParseError`, not `JsonParseError`).
- **`reduce` under `baml run -e`:** inline-closure inference can fail; if it does, move the reducer into a named function in `baml_src` and call that function from `run -e`.
- **`Array.insert` argument order:** it is `insert(item, idx)`, not `insert(idx, item)` like many other languages.

## LLM functions + tests, minimum viable

```baml
class Intent {
    kind: "billing" | "support" | "other",
    confidence: float,
}

function classify(text: string) -> Intent {
    client: "openai/gpt-4o-mini"
    prompt: #"Classify: {{ text }}  {{ ctx.output_format }}"#   // ALWAYS include ctx.output_format
}

// A single test needs no wrapper — `testset "name" { ... }` only GROUPS multiple tests.
test "parses" {
    let r = baml.json.from_string<Intent>(#"{ "kind": "support", "confidence": 0.9 }"#);
    assert.equal(r.kind, "support")  // trailing expr → no `;`; asserts: equal is_true not_null contains
}
```

The return type is the schema; prompts are `#"..."#` block strings with Jinja inside `{{ }}`. Every LLM function gets a `name$parse(raw)` companion for parsing captured replies in tests.

**Workflow: sketch → `baml run -e` / `baml check` constantly → `baml describe` anything unfamiliar → `baml test` → `baml fmt`.**
