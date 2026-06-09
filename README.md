# baml-skill — Claude Code plugin for BAML

One Claude Code skill that teaches the agent to write idiomatic BAML. It auto-triggers when Claude opens a `.baml` file or is asked "how do I install / use BAML?".

The premise: **BAML is two things in one file** — a statically-typed, expression-oriented *language* (basically TypeScript with `snake_case` methods and `name type` class fields: types, classes, generics, closures, optional chaining, control flow, `throws`/`catch`/`catch_all`, a stdlib) and a small declarative *DSL* for LLM calls (`client<llm>`, `function … { client:  prompt: }`, `generator`, `test`) that desugars into that language. The skill is organized around that split, dense with code examples; for any stdlib name or signature it doesn't show, the agent runs `baml describe` instead of guessing.

Every code example in the skill is verified to compile against the `baml_language` CLI.

Without it, agents invent stdlib methods (`baml.json.decode_str`, `s.contains()`), forget `{{ ctx.output_format }}` on prompts, and probe for things that don't exist. With it, they reach for `baml.json.from_string<T>`, snake_case names, and `client: "openai/gpt-4o-mini"` on the first try.

## Install

```
/plugin marketplace add BoundaryML/baml-skill
/plugin install baml@boundaryml-baml
```

The skill auto-loads in any Claude Code session.

## What it covers

A single `core` skill, heavy on code, light on prose:

- Install + the `baml describe / run / test / fmt / generate` agent loop, project layout & `ns_` namespaces
- **The language** — pretty much every part: types & literals (incl. media + literal types), variables/blocks/expressions, functions (tail returns, `-> null` unit, factories, methods, higher-order, lambdas, closures), classes/enums/**generics**, control flow (`if`/`while`/for-in/**C-style for**/`match`), **optional chaining** (`?.`/`?.[]`/`?.()`/`??`), collections & strings (the real method surface), number math, JSON, `throws`/`catch`/**`catch_all`**, and the rest of the stdlib (fs/http/sys/env/io/log/assert)
- **The DSL** — the LLM layer that desugars into the language: `client<llm>` blocks + `client:` shorthand, LLM functions with Jinja prompts and `{{ ctx.output_format }}`, the `$parse` companion, pipelines, the Python `baml_sdk` generator/bridge, and deterministic testing (incl. loop-generated testsets)
- **How BAML differs from TypeScript** — `name type` fields, `for...in` iterates values, `null` is unit, no ternary, no `.filter`, `.length()` is bytes, non-exhaustive `catch`, panicking index, and the rest
- The throughline: **anything not shown → `baml describe <name>`**

## Layout

```
baml-skill/
├── .claude-plugin/
│   └── marketplace.json              # marketplace catalog (one plugin: baml at ./plugins/baml)
├── README.md                         # this file
└── plugins/baml/
    ├── .claude-plugin/plugin.json    # plugin manifest
    └── skills/
        └── core/SKILL.md             # the skill
```

## Editing

```bash
# Symlink the work-in-progress copy into your global skills dir for fast iteration.
ln -sf "$PWD/plugins/baml/skills/core" ~/.claude/skills/baml-core-dev
# Edit plugins/baml/skills/core/SKILL.md, then restart your session; skills auto-reload.
```

When happy, bump `version` in `plugins/baml/.claude-plugin/plugin.json` and commit.

## Versioning

- **0.1.x** — content corrections, no structural changes.
- **0.2.x** — added or removed sub-skills, restructured.
- **0.3.x** — aligned to the canonical BAML agent guide.
- **0.4.x** — collapsed the five skills into one lean, example-dense skill.
- **0.5.x** — restructured around the language/DSL split; expanded language coverage; every example verified against the CLI.
- **0.6.x** — aligned to the baml_language rewrite: `name type` fields, `-> null` unit, generics, optional chaining, `catch_all`, C-style for, richer stdlib; reconciled against a team syntax reference + the compiler (current).
- **1.0.0** — stable.

## License

Apache-2.0.
