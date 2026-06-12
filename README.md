# baml-skill — Claude Code plugin for BAML

One Claude Code skill that teaches the agent to write idiomatic BAML. It auto-triggers when Claude opens a `.baml` file or is asked "how do I install / use BAML?".

The premise: **BAML is two things in one file** — a statically-typed, expression-oriented *language* (basically TypeScript with `snake_case` methods and `name type` class fields: types, classes, generics, closures, optional chaining, control flow, `throws`/`catch`/`catch_all`, a stdlib) and a small declarative *DSL* for LLM calls (`client<llm>`, `function … { client:  prompt: }`, `generator`, `test`) that desugars into that language.

The skill is deliberately minimal and **describe-first**: it names the handful of traps that trip up agents, shows one minimum-viable LLM function + test, and otherwise points the agent at `baml describe` for every stdlib name, type, and signature rather than padding the prompt with examples it would guess wrong. The CLI is the reference. This is the arena-winning `micro-describe` variant.

Every code example in the skill is verified to compile against the `baml_language` CLI.

Without it, agents invent stdlib methods (`baml.json.decode_str`, `s.contains()`), forget `{{ ctx.output_format }}` on prompts, and probe for things that don't exist. With it, they reach for `baml.json.from_string<T>`, snake_case names, and `client: "openai/gpt-4o-mini"` on the first try.

## Install

```
/plugin marketplace add BoundaryML/baml-skill
/plugin install baml@boundaryml-baml
```

The skill auto-loads in any Claude Code session.

## What it covers

A single `core` skill, minimal and describe-first:

- Install + the `baml describe / run / test / fmt` agent loop — `baml describe <name>` is the reference for any module/type/method/signature
- **The five fatal traps** the language model otherwise gets wrong: `name type` fields (no colon/comma), trailing-expression blocks + `-> null` unit, `for (let x in xs)` over values, no implicit string coercion / panicking index / `.collect()` after `.filter`, type-only non-exhaustive `catch`
- One **minimum-viable LLM function + test** — `client:`/`prompt:` blocks with `{{ ctx.output_format }}`, the return type as schema, the `name$parse` companion, `testset`/`test` with `assert.*`
- The throughline: **anything not shown → `baml describe <name>`; check it with `baml run -e`**

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
- **0.6.x** — aligned to the baml_language rewrite: `name type` fields, `-> null` unit, generics, optional chaining, `catch_all`, C-style for, richer stdlib; reconciled against a team syntax reference + the compiler.
- **0.7.x** — split into four skills (core, bridges, serving, testing), each verified against the shipped CLI.
- **0.8.x** — collapsed back to one minimal, describe-first `core` skill; the arena-winning `micro-describe` variant (current).
- **1.0.0** — stable.

## License

Apache-2.0.
