#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d "$root/tests/.shelley-hooks.XXXXXX")
trap 'rm -rf -- "$work"' EXIT
hook="$root/vm/shelley-hooks/system-prompt"

cat > "$work/input" <<'TEXT'
The user's exe.dev email is first@example.com
You are an assistant.

The user's exe.dev email is second@example.com
The user's exeXdev email is keep@example.com
 The user's exe.dev email is keep@example.com
Keep the user's exe.dev email is text.
The user's exe.dev email is
Keep the remaining instructions.
The user's exe.dev email is last@example.com
TEXT
cat > "$work/expected" <<'TEXT'
You are an assistant.

The user's exeXdev email is keep@example.com
 The user's exe.dev email is keep@example.com
Keep the user's exe.dev email is text.
The user's exe.dev email is
Keep the remaining instructions.
TEXT

"$hook" < "$work/input" > "$work/actual"
cmp "$work/expected" "$work/actual"
"$hook" < "$work/expected" > "$work/actual"
cmp "$work/expected" "$work/actual"

printf 'PASS: system-prompt hook removes only the exe.dev email lines\n'
