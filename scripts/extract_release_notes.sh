#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <tag> <changelog-path>" >&2
  exit 64
fi

tag="$1"
changelog_path="$2"

if [[ ! -f "$changelog_path" ]]; then
  echo "missing changelog: $changelog_path" >&2
  exit 66
fi

notes="$(
  awk -v target="## [$tag]" '
    index($0, target) == 1 { in_section = 1; next }
    in_section && index($0, "## [") == 1 { exit }
    in_section { print }
  ' "$changelog_path"
)"

notes="${notes#"${notes%%[!$'\n\r\t ']*}"}"
notes="${notes%"${notes##*[!$'\n\r\t ']}"}"

if [[ -z "$notes" ]]; then
  echo "no changelog entry found for $tag in $changelog_path" >&2
  exit 65
fi

printf '%s\n' "$notes"
