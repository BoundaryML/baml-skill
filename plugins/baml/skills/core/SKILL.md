---
name: core
description: Minimal BAML skill. BAML is a statically-typed, expression-oriented language with first-class LLM functions — TypeScript-like, snake_case methods, backtick strings with ${...} interpolation. The CLI is the reference: run `baml describe` for every name and `baml run -e` to check everything. Never guess stdlib.
---

# baml — describe-first

**What BAML is:** one file, two things. A statically-typed, expression-oriented *language* — TypeScript with `snake_case` methods, `name: type,` fields, enums, interfaces, generics, closures, optional chaining, backtick strings with `${...}` interpolation, `.to_string()` on any value, a real stdlib. And a declarative *DSL* for LLM calls (`function … { client: prompt: }`, `test`) that desugars into it, so a model's structured output is just a typed return value.

**The CLI is the documentation. Discover, don't guess:**

```bash
brew install baml                # CLI binary: `baml`

baml init                        # new project (baml.toml + baml_src/)
baml describe baml.json          # ← THE reference for any module/type/method/signature
baml describe Array              #   (Array, String, Map, assert, match, patterns, spawn, python, ...)
                                 #   ends with "… N more lines"? re-run with `--budget <N>`
baml check                       # compile-check the project
baml run -e 'expr'               # eval an expression — fast feedback + syntax check
baml test --list && baml test    # run every test/testset block
baml fmt baml_src/main.baml      # canonicalize (still catching up to backtick prompts)
```

`baml describe <name>` prints the **full source body** of stdlib functions — the fastest way to verify behavior, and the only path for embedded builtins like `assert` (no on-disk file). Pure functions need no test/client — check them with `baml run -e 'add(2, 3)'`.

Mostly it behaves like JavaScript/TypeScript, with very similar syntax — but BAML is more sound/strict.

## Best practices (the idiomatic path)

- **LLM function = typed return.** The RETURN TYPE *is* the schema the model must produce (`class`, `enum`, literal union, `string[]`, `T?`). Structured output is just a typed value — hand it to ordinary code.
- **Prompts are backtick strings with `${...}` interpolation.** Write `prompt:` `` `… ${arg} …` ``, and **always inject `${ctx.output_format}`** for a structured return. Escape with `` \` `` / `\${`; nest with extra backticks.
- **Shape the schema with field attributes.** `@description("…")` adds a `///` hint the model sees in `${ctx.output_format}`; `@alias("name")` renames the emitted JSON key. Chain: `tags: string[] @alias("labels") @description("…")`.
- **Test the pure code, not the model.** Unit-test orchestration/post-processing on literal data with `assert.*`. Calling an LLM function in a `test` makes a real request — not an offline test. (`f$parse`/`f$render_prompt`/`f$build_request` exist for debugging.)
- **Build strings with interpolation, not coercion.** `` `score=${n}` `` stringifies any value (implicit `.to_string()`); call `.to_string()` for the string alone. `+` needs both sides already strings (`"n=" + 5` won't compile).
- **`catch` for some, `catch_all` for all.** `expr catch (e) { baml.errors.ParseError => fallback }` handles a *specific* error; `expr catch_all (e) { _ => fallback }` is *exhaustive* — for a workflow top / entrypoint. Errors propagate implicitly; callers needn't re-declare.
- **Interfaces = shared behavior + dynamic dispatch.** `interface I { function m(self) -> T }` (methods may have default bodies); a class opts in via `implements I { … }`; a value typed `I` (or `I[]`) dispatches to the implementor at runtime.
- **Pattern matching.** `match (v) { … }` over values/types; arms are `pattern => expr` — literals, `let x: T` (bind + narrow), class destructure `T { f: let y }`, or-patterns `A | B`, guards `… if cond`, `_`; must be exhaustive. Also `v is T` → bool (narrows) and `if let x: T = v { … } else { … }`. `baml describe patterns`.
- **Concurrency = green threads.** `spawn { … }` launches a background task, `await` collects it, `baml.future.all(list)` awaits many — fan out independent LLM/HTTP calls. `baml describe spawn`.
- **Call BAML from Python / TS.** Declare a `[generator.<name>]` in `baml.toml`, run `baml generate`, then import the typed `baml_sdk`. Install + usage: `baml describe python` / `baml describe typescript` / `baml describe baml_sdk`.
- **Safe access over indexing.** Subscript panics on a missing index/key; use `.at(i)`/`.get(k)` (→ `T?`), reach through with `?.`, default with `??` (parenthesize: `(m.get(k) ?? 0) + 1`).
- **Stdlib methods are snake_case, called on a value.** Some return new, some mutate in place, a few do both (`sort_by_key` sorts the receiver *and* returns it) — to read the docs, `baml describe <word/type/identifier/keyword/etc>`.
- **Class fields `name: type,`; construct `Type { field: val }`.** Methods take a bare `self`; factories are free functions. Enums: `enum E { A, B }`, access `E.A`.
- **Blocks are expressions** — last expression is the value (no `;`); `return x;` for early exit; `-> null` for unit. `for (let x in xs)` iterates VALUES. Closures `(x) -> { ... }` infer param/return from context (annotate `(x: T) -> R` only when ambiguous; the `->` is required). `.map`/`.filter` return arrays directly (no `.collect()`). Empty map needs a type: `let m: map<string, int> = {};`.
- **Tests:** lone `test "name" { ... }` (no wrapper); `testset` only GROUPS. Asserts (only 4): `assert.equal`/`is_true`/`not_null`/`contains`. `assert.equal` compares structurally; `baml.deep_equals(a, b)` is the bool form. Last assert: no trailing `;`.

For anything not shown (signatures, niche stdlib, advanced features), run **`baml describe <name>`** — the CLI is the docs; never guess the stdlib.

## Example 1 — LLM DSL + glue (schema, attributes, client, backtick prompt, post-processing)

```baml
// The return type IS the schema; @description/@alias shape what the model sees.
enum Priority { High, Low }

class LineItem {
    name: string,
    amount: float,
    priority: Priority,
}

class Invoice {
    vendor: string @alias("seller"),
    status: "draft" | "final" @description("invoice state"),
    items: LineItem[],
    note: string?,
}

client<llm> Fast {
    provider: openai,
    options: { model: "gpt-4o-mini", api_key: env.OPENAI_API_KEY },
}

function Extract(raw: string) -> Invoice {
    client: Fast                                  // or shorthand: "openai/gpt-4o-mini"
    prompt: `Extract the invoice. ${ctx.output_format}\n${raw}`
}

// Structured output is just a typed value — hand it to ordinary code.
// Closure params/return infer from context; only the -> is required.
function high_total(inv: Invoice) -> float {
    inv.items.filter((i) -> { i.priority == Priority.High }).reduce((a, i) -> { a + i.amount }, 0.0)
}

test "post-process a literal Invoice — no model call" {
    let inv = Invoice {
        vendor: "Acme", status: "final", note: null,
        items: [LineItem { name: "srv", amount: 900.0, priority: Priority.High },
                LineItem { name: "mug", amount: 12.0, priority: Priority.Low }],
    };
    assert.is_true(baml.deep_equals(high_total(inv), 900.0))
}
```

## Example 2 — the language (methods, interpolation, closures, maps, json, errors)

```baml
// BAML is a real language — no LLM here.
enum Tier { Free, Pro }

class User {
    name: string,
    tier: Tier,
    score: int,
    // method (bare self) + ${} interpolation (implicit .to_string() on the int)
    function label(self) -> string { `${self.name.to_upper_case()}:${self.score}` }
}

function make_user(name: string, score: int) -> User { User { name: name, tier: Tier.Pro, score: score } }

// inferred closures; sort_by_key; optional chaining + ?? over a possibly-null .at
function top_label(us: User[]) -> string {
    us.sort_by_key((u) -> { 0 - u.score }).at(0)?.label() ?? "none"
}

// map<string,int> via for-let-in; .get ?? default; explicit .to_string()
function tier_counts(us: User[]) -> map<string, int> {
    let counts: map<string, int> = {};
    for (let u in us) { let _ = counts.set(u.tier.to_string(), (counts.get(u.tier.to_string()) ?? 0) + 1); }
    counts
}

function roundtrip(u: User) -> User { baml.json.from_string<User>(baml.json.to_string(u)) }

// `catch` with a typed arm handles ONE specific error
function safe_parse(s: string) -> int { baml.Int.parse(s) catch (e) { baml.errors.ParseError => -1 } }

test "lang" {
    let us = [make_user("ada", 90), make_user("bo", 30)];
    assert.equal(top_label(us), "ADA:90");
    assert.equal((tier_counts(us).get("Pro") ?? 0), 2);
    assert.equal(roundtrip(make_user("zoe", 7)).name, "zoe");
    assert.equal(safe_parse("42"), 42);
    assert.equal(safe_parse("x"), -1)
}
```

## Example 3 — interfaces (shared behavior, default method, dynamic dispatch)

```baml
interface Animal {
    function sound(self) -> string
    function describe(self) -> string { `${self.sound()}!` } // default method
}

class Dog {
    name: string,
    implements Animal { function sound(self) -> string { "woof" } }
}

class Cat {
    indoor: bool,
    implements Animal {
        function sound(self) -> string { "meow" }
        function describe(self) -> string { `quiet ${self.sound()}` } // override
    }
}

// an Animal[] holds any implementor; calls dispatch dynamically
function chorus(animals: Animal[]) -> string {
    animals.map((a) -> { a.describe() }).join(" ")
}

test "interfaces" {
    let animals: Animal[] = [Dog { name: "Rex" }, Cat { indoor: true }];
    assert.equal(chorus(animals), "woof! quiet meow")
}
```

## Example 4 — pattern matching (`match` over values + types, `is`, `if let`)

```baml
class Circle { r: int }
class Rect { w: int, h: int }
type Shape = Circle | Rect

function area(s: Shape) -> int {
    match (s) {
        Circle { r: 0 } => 0,                           // literal field, no binding
        let c: Circle => 3 * c.r * c.r,                 // typed binding (matches + narrows)
        Rect { w: let w, h: let h } if w == h => w * w, // destructure + guard
        _ => 0,                                         // wildcard
    }
}

function classify(n: int) -> string {
    match (n) {
        0 => "zero",
        1 | 2 | 3 => "small",     // or-pattern
        let x if x < 0 => "neg",  // binding + guard
        _ => "big",
    }
}

// `is` -> bool (and narrows); `if let PATTERN = expr { } else { }`
function label(s: Shape) -> string {
    if (s is Circle) {
        "circle"
    } else if let r: Rect = s {
        `rect ${r.w}x${r.h}`
    } else {
        "?"
    }
}

test "patterns" {
    assert.equal(area(Circle { r: 2 }), 12);
    assert.equal(area(Rect { w: 3, h: 3 }), 9);
    assert.equal(classify(2), "small");
    assert.equal(classify(-5), "neg");
    assert.equal(label(Circle { r: 1 }), "circle");
    assert.equal(label(Rect { w: 2, h: 4 }), "rect 2x4")
}
```

## Concurrency — green threads (parallelize LLM / HTTP calls)

`spawn { … }` launches a background task; `await` collects it; `baml.future.all(list)` awaits many in order. Run `baml describe spawn` for the details.

```baml
function fetch_all(urls: string[]) -> string[] {
    // each request runs concurrently; await all results in order
    await baml.future.all(urls.map((u) -> { spawn { baml.http.fetch(u).text() } }))
}
```

**Workflow: sketch → `baml run -e` / `baml check` constantly → `baml describe` anything unfamiliar → `baml test`.**
