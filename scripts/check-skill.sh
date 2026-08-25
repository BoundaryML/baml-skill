#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
skill_file="$repo_root/plugins/baml/skills/core/SKILL.md"
baml_bin="${BAML_BIN:-baml}"
audit_dir="$(mktemp -d "${TMPDIR:-/tmp}/baml-skill-check.XXXXXX")"

cleanup() {
    rm -rf "$audit_dir"
}
trap cleanup EXIT

"$baml_bin" init "$audit_dir" --name baml_skill_check --quiet

awk '
    /^```baml[[:space:]]*$/ {
        in_fence = 1
        fence_count++
        next
    }
    /^```[[:space:]]*$/ && in_fence {
        in_fence = 0
        print ""
        next
    }
    in_fence { print }
    END {
        if (in_fence) {
            print "unclosed BAML code fence" > "/dev/stderr"
            exit 1
        }
        if (fence_count == 0) {
            print "no BAML code fences found" > "/dev/stderr"
            exit 1
        }
    }
' "$skill_file" > "$audit_dir/baml_src/main.baml"

"$baml_bin" check --project "$audit_dir"
"$baml_bin" fmt --dry-run "$audit_dir/baml_src/main.baml" > /dev/null
"$baml_bin" test --project "$audit_dir"
