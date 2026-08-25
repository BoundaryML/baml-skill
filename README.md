# baml-skill

Agent instructions for writing idiomatic BAML. The skill is deliberately describe-first: it documents the high-value language and LLM workflow rules, then treats `baml describe` as the reference for exact APIs.

Every BAML example in the skill is compiled and tested against the latest published nightly release in CI.

## Install

From a BAML project, run:

```bash
baml agent install
```

This installs `baml-core` for supported agents and archives superseded versions under `baml-old_skills`.

Claude Code users can also install the plugin directly:

```text
/plugin marketplace add BoundaryML/baml-skill
/plugin install baml@boundaryml-baml
```

## Contents

```text
baml-skill/
|-- .claude-plugin/marketplace.json
|-- .github/workflows/check-skill.yml
|-- plugins/baml/
|   |-- .claude-plugin/plugin.json
|   `-- skills/core/SKILL.md
`-- scripts/check-skill.sh
```

The core skill covers BAML syntax, types, clients, LLM functions, tests, interfaces, patterns, errors, concurrency, resource cleanup, namespaces, and the CLI workflow.

## Validate

Run all BAML snippets with a selected CLI:

```bash
BAML_BIN=baml scripts/check-skill.sh
```

CI downloads the newest published BAML nightly from GitHub, verifies its checksum, and runs the same check daily and on every change.

## Editing

Edit `plugins/baml/skills/core/SKILL.md`, run `scripts/check-skill.sh`, and bump the plugin version for a release.

## License

Apache-2.0.
