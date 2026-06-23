---
name: core
description: Minimal BAML skill. BAML is a statically-typed, expression-oriented language with first-class LLM functions — TypeScript-like, snake_case methods. The CLI is the reference: run `baml describe` for every name and `baml run -e` to check everything. Never guess stdlib.
---

# baml — describe-first

**What BAML is:** one file holds two things. A statically-typed, expression-oriented *language* — basically TypeScript with `snake_case` methods and `name: type,` class fields: types, classes, generics, closures, optional chaining, control flow, `throws`/`catch`, a real stdlib. And a small declarative *DSL* for LLM calls (`function … { client:  prompt: }`, `test`) that desugars into that language, so a model's structured output is just a typed return value. You write reliable LLM functions and the small programs that orchestrate them in the same typed language.

**The CLI is the documentation. Discover, don't guess:**

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

For builtin/stdlib functions, `baml describe <function-name>` prints the **full source body** (not just the signature) — the fastest way to verify behavior, and the primary discovery path for functions in embedded builtins like `assert` that have no on-disk file to read (e.g. `baml describe assert.equal` dumps the whole `<builtin>/assert/assert.baml` definition).

Pure (non-LLM) functions need no test block, testset wrapper, or client config — verify them instantly with `baml run -e 'add(2, 3)'`. This is the fastest feedback path for arithmetic, string-processing, and utility functions.

## The five fatal traps (everything else, `baml describe` it)

1. Class fields are `name: type,` — `baml fmt` writes the colon + comma (bare `name type` also parses, but fmt normalizes). Construction matches: `Point { x: 1 }`. Methods live in the class body and take a bare `self` (no type annotation); factories are free functions with no `self`.
2. Last expression in a block is its value (Rust-style). Early exit: `return x;` with trailing `;`. No-value functions: `-> null` + trailing `null`. There is no `mut` keyword — `let` bindings are already reassignable, so `let mut i = 0` is a parse error.
3. `for (let x in xs)` iterates VALUES and requires `let`. `if`/`match`/blocks are expressions; `match (v) { 0 => "a", _ => "b" }`. `while (cond) { ... }` also exists for imperative loops.
4. No implicit string coercion (`"n=" + 5` won't compile — `baml.unstable.string(5)`); indexing panics out of bounds (use `.at(i)`/`.get(k)` → `T?`, reach through with `?.`, default with `??`); closures are `(x: T) -> R { ... }` (the `=>` arrow is match-only — `.filter`/`.map` return arrays directly, no `.collect()`); map keys must be `string` and an empty `{}` literal needs a type annotation (`let m: map<string, int> = {}`).
5. `catch` arms are type-only and non-exhaustive: `f(x) catch (e) { BadInput => fallback }`; callee `throws` propagate implicitly unless caught, so callers do not need to re-declare `throws T` unless they want static enforcement at their own signature boundary; runtime panics are catchable too, via fully-qualified arms (`expr catch (e) { baml.panics.DivisionByZero => fallback }`, likewise `baml.panics.IndexOutOfBounds`), and like any arm the match is selective — a non-matching arm re-propagates the panic. (When available, `int.try_parse(s) -> int | null` is the non-throwing alternative.)

## A worked example (verified against the CLI)

One program that exercises most of the traps above — class methods, the
expression-oriented body, `match`/`while`/`for`, explicit coercion, optional
access, typed closures, and a fully-qualified panic `catch`:

```baml
class WordCount {
    word: string,
    count: int,

    // Method — declared in the class body, takes a bare `self` (no type).
    function render(self) -> string {
        // No implicit string coercion: turn the int into a string first.
        let n = baml.unstable.string(self.count);
        // `match` is an expression; the chosen arm's value flows out.
        let bar = match (self.count) {
            0 => "",
            _ => {
                // `let` is reassignable (there is no `mut`), `while` works.
                let i = 0;
                let out = "";
                while (i < self.count) {
                    out = out + "#";
                    i = i + 1;
                }
                out
            }
        };
        self.word + " " + bar + " (" + n + ")"   // last expression = return value
    }
}

class Report {
    total: int,
    top: WordCount[],
}

// Factory — a free function, no `self`. Construction is `Type { field: val }`.
function word_count(word: string, count: int) -> WordCount {
    WordCount { word: word, count: count }
}

function tally(words: string[]) -> Report {
    // Map keys must be strings; an empty `{}` needs a type annotation so its
    // key/value types aren't inferred as `never`.
    let counts: map<string, int> = {};
    // `for (let x in xs)` iterates VALUES and requires the `let`.
    for (let raw in words) {
        let w = raw.to_lower_case().trim();
        if (w.length() > 0) {
            // `??` binds looser than `+`, so parenthesize: (get ?? 0) + 1.
            counts.set(w, (counts.get(w) ?? 0) + 1);
        }
    }

    // Closures need typed params + a return annotation here, and `.map`
    // returns an array directly — there is no `.collect()`.
    let pairs = counts.keys().map((k: string) -> WordCount {
        word_count(k, counts.get(k) ?? 0)
    });

    // Rank descending by count, keep the top 3.
    let ranked = pairs.sort_by_key((wc: WordCount) -> int { -wc.count });
    let top = ranked.slice(0, ranked.length().min(3));

    Report { total: words.length(), top: top }
}

// Runtime panics ARE catchable via fully-qualified `catch` arms. The match is
// selective — a non-matching panic re-propagates.
function safe_div(hits: int, total: int) -> int {
    (hits / total) catch (e) { baml.panics.DivisionByZero => 0 }
}

test "report ranks and renders" {
    let r = tally(["the", "fox", "the", "dog", "The", "fox", "the"]);
    assert.equal(r.total, 7);
    // `.at(i)` returns `T?` instead of panicking out of bounds. There is no `!`
    // operator — reach through with `?.` and supply a fallback with `??`.
    let first = r.top.at(0);
    assert.equal(first?.word ?? "", "the");
    assert.equal(first?.count ?? 0, 4);
    assert.equal(word_count("hi", 2).render(), "hi ## (2)")
}

test "safe_div swallows divide-by-zero" {
    assert.equal(safe_div(3, 0), 0);
    assert.equal(safe_div(9, 3), 3)
}
```

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
