#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d "$root/tests/.mise-smoke.XXXXXX")
container=""
cleanup() {
	[[ -z "$container" ]] || docker rm "$container" >/dev/null
	rm -rf -- "$work"
}
trap cleanup EXIT
image=$(awk '/^COPY --from=ghcr.io\/jdx\/mise:/ { sub(/^--from=/, "", $2); print $2 }' "$root/Dockerfile")
[[ -n "$image" ]]
mkdir -p "$work/repo" "$work/home"
: > "$work/global.toml"
cat > "$work/repo/mise.toml" <<'TOML'
[tasks.apply]
dir = "{{config_root}}"
run = "printf 'applied\\n' > result"
TOML

# The vendor image contains the binary, but no shell to execute a task.
container=$(docker create "$image")
docker cp "$container:/usr/local/bin/mise" "$work/mise"
run_mise() {
	env -i PATH="$PATH" HOME="$work/home" XDG_CONFIG_HOME="$work/config" \
		XDG_DATA_HOME="$work/data" XDG_STATE_HOME="$work/state" \
		XDG_CACHE_HOME="$work/cache" MISE_OFFLINE=1 MISE_CEILING_PATHS="$work" \
		MISE_GLOBAL_CONFIG_FILE="$work/global.toml" MISE_SYSTEM_CONFIG_DIR="$work/system" \
		"$work/mise" "$@"
}
run_mise --version
run_mise trust "$work/repo/mise.toml"
run_mise -C "$work/repo" tasks info apply --json > "$work/task.json"
run_mise -C "$work/repo" run apply </dev/null
[[ $(cat "$work/repo/result") == applied ]]
jq -e --arg source "$work/repo/mise.toml" '.source == $source' "$work/task.json" >/dev/null
printf 'PASS: image-pinned mise trust, task source, and unattended apply\n'
