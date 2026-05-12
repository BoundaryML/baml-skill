# baml-skill — Claude Code plugin for BAML

Five Claude Code skills that teach the agent to write idiomatic BAML. They auto-trigger when Claude opens a `.baml` file or is asked "how do I install / use BAML?".

BAML is a typed language for reliable LLM functions, structured output, and small orchestration programs. Without these skills, agents tend to invent stdlib methods (`baml.json.decode_str`, `s.contains()`), forget `{{ ctx.output_format }}` on prompts, and waste turns probing for things that don't exist. With them, they reach for `baml.json.from_string<T>`, snake_case function names, and `client: "openai/gpt-4o-mini"` on the first try.

## Install

```
/plugin marketplace add BoundaryML/baml-skill
/plugin install baml@boundaryml-baml
```

All five skills land together. They auto-load in any Claude Code session.

## The five skills

| Skill | When it loads |
|---|---|
| `baml:core` | **Always** — any `.baml` file or BAML question. Install, project layout with `ns_*` namespaces, the `baml run / describe / fmt / generate` agent loop, syntax essentials (class fields `name: Type,`, snake_case functions, type aliases ending in `;`), stdlib (Collections/Strings, JSON via `baml.json.*`, files/HTTP/shell/env), `match` + typed `throws / catch`, common pitfalls. |
| `baml:llm-functions` | When defining `function ... -> T { client: ...  prompt #"..."# }`. `client<llm>` declarations (UpperCamelCase, `provider` + `options`), the `client: "provider/model"` shorthand, Jinja prompts with `{{ ctx.output_format }}`, structured output. |
| `baml:pipelines` | When composing multiple BAML functions. Function-to-function composition, routing via `match` (with `let s: T =>` narrowing), error propagation through `throws T`, host-side fan-out. |
| `baml:testing` | When writing or running `testset` / `test` blocks. Deterministic LLM tests via cached JSON fixtures + `baml.json.from_string<T>(raw)`. (NOT a `$parse` companion — that pattern is deprecated.) |
| `baml:bridges` | When integrating with host code or reaching for a host capability. Today's supported host is Python via `baml generate` -> the `baml_sdk` package. Covers the `generator target { ... }` block (in a `.baml` file, not TOML), the `b.<function>` API, and the BAML -> shell bridge pattern. |

`core` is the entry point. Claude is told to load it first when it sees a BAML task, then optionally pull in any of the other four based on what the task actually requires.

## Layout

```
baml-skill/
├── .claude-plugin/
│   └── marketplace.json              # marketplace catalog (one plugin: baml at ./plugins/baml)
├── README.md                         # this file
└── plugins/baml/
    ├── .claude-plugin/plugin.json    # plugin manifest
    └── skills/
        ├── core/SKILL.md             # foundation; always-load
        ├── llm-functions/SKILL.md    # function ... { client: ...  prompt #"..."# }
        ├── pipelines/SKILL.md        # composing typed LLM stages
        ├── testing/SKILL.md          # testset blocks + cached JSON fixtures
        └── bridges/SKILL.md          # baml_sdk Python client + shell bridges
```

## Editing the skills

```bash
# Symlink the work-in-progress copy into your global skills dir for fast iteration.
for s in core llm-functions pipelines testing bridges; do
  ln -sf "$PWD/plugins/baml/skills/$s" ~/.claude/skills/baml-$s-dev
done
# Edit any plugins/baml/skills/<name>/SKILL.md
# Restart your Claude Code session; skills auto-reload.
```

When happy, bump `version` in `plugins/baml/.claude-plugin/plugin.json` and commit.

## Versioning

- **0.1.x** — content corrections, no structural changes.
- **0.2.x** — added or removed sub-skills, restructured.
- **0.3.x** — aligned to the canonical BAML agent guide (current).
- **1.0.0** — stable.

## Canonical source

The skill content tracks the BAML team's canonical agent guide:
https://gist.github.com/hellovai/4abc7de0ca4a3f4a07b5b3e6b4e0f77e

If the gist updates, sync the affected skill files and bump `version` in `.claude-plugin/plugin.json`.

## License

Apache-2.0.
