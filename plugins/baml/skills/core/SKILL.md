---
name: core
description: Minimal BAML orientation. Load when working in .baml files or answering any BAML question. Gives the handful of ways BAML differs from TypeScript, two verified examples, and the one habit that matters — run `baml describe <name>` for anything not shown here instead of guessing.
---

# baml — the short version

BAML is a statically-typed, expression-oriented language with first-class LLM
functions. It reads like TypeScript with five twists:

- Class fields are `name type` — no colon, no comma. Colons appear in
  parameters, `let` annotations, map literals, struct construction.
- Methods and stdlib are `snake_case`; the last expression of a block is its
  value (no `return` needed at the end).
- `if`, `match`, blocks, and `catch` are expressions. `for (let x in xs)`
  iterates values and requires `let`.
- No implicit string coercion (`"n=" + 5` won't compile) and no `.filter`;
  indexing `a[0]` panics out of bounds — use `.at(i)`, which returns `T?`.
- An LLM call is just a function whose body is `client:` + `prompt:`; its
  return type is the output schema.

## Example 1 — the language

```baml
class Greeting { name string  message string }

function greet(name: string) -> Greeting {
  Greeting { name: name, message: "hi " + name }
}

function describe_size(n: int) -> string {
  match (n) {
    0 => "zero",
    1 | 2 | 3 => "small",
    _ => "big",
  }
}
```

## Example 2 — an LLM function

```baml
class Intent {
  kind "billing" | "support" | "spam"
  confidence float
}

function classify(text: string) -> Intent {
  client: "openai/gpt-4o-mini"
  prompt: #"Classify: {{ text }}  {{ ctx.output_format }}"#
}
```

## Working loop

```bash
baml init                       # new project (writes the required baml.toml)
baml run --list                 # compile + list functions
baml run -e 'greet("ana")'      # evaluate an expression (also a syntax check)
baml describe <name>            # ← THE tool: docs for any symbol, module, or type
```

**That's the whole skill. For anything else — stdlib names, signatures, CLI
flags, generator blocks, testing, calling BAML from Python — run
`baml describe <name>` (e.g. `baml describe Array`, `baml describe baml.json`,
`baml describe baml.http`) or `<command> --help`, and trust what they say over
any guess.**
