#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d "$root/tests/.setup-test.XXXXXX")
trap 'rm -rf -- "$work"' EXIT
mkdir "$work/bin"

cat > "$work/bin/curl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'discover\n' >> "$TEST_CASE/events"
[[ ${FAIL_DISCOVERY:-0} == 0 ]] || exit 22
cat "$TEST_CASE/integrations.json"
SH

cat > "$work/bin/git" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
while [[ ${1:-} == -c ]]; do shift 2; done
if [[ ${1:-} == clone ]]; then
	printf 'clone\n' >> "$TEST_CASE/events"
	[[ ${FAIL_CLONE:-0} == 0 ]] || exit 128
	destination=${!#}
	mkdir -p "$destination/.git"
	printf '%s\n' "${@: -2:1}" > "$destination/.git/origin"
	if [[ ${NO_CONFIG:-0} == 0 ]]; then
		printf '[tasks.apply]\nrun = "true"\n' > "$destination/mise.toml"
	fi
	exit 0
fi
[[ ${1:-} == -C ]]
directory=$2
shift 2
case "$*" in
	'config --local --get remote.origin.url') cat "$directory/.git/origin" ;;
	'status --porcelain')
		[[ ${FAIL_STATUS:-0} == 0 ]] || exit 128
		[[ ! -e "$directory/.dirty" ]] || printf ' M mise.toml\n'
		;;
	'rev-parse HEAD') printf '1111111111111111111111111111111111111111\n' ;;
	*) printf 'Unexpected git invocation: %s\n' "$*" >&2; exit 1 ;;
esac
SH

cat > "$work/bin/mise" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ ${1:-} == trust ]]; then
	[[ $2 == "$XDG_DATA_HOME/exeslim/setup/mise.toml" ]]
	printf 'trust\n' >> "$TEST_CASE/events"
	exit 0
fi
[[ ${1:-} == -C ]]
directory=$2
shift 2
case "$*" in
	'tasks info apply --json')
		[[ ${NO_TASK:-0} == 0 ]] || exit 1
		source="$directory/mise.toml"
		[[ ${GLOBAL_TASK:-0} == 0 ]] || source="$HOME/.config/mise/config.toml"
		jq -n --arg source "$source" '{name:"apply",source:$source}'
		;;
	'run apply')
		printf 'apply\n' >> "$TEST_CASE/events"
		[[ ${FAIL_APPLY:-0} == 0 ]] || exit 42
		;;
	*) printf 'Unexpected mise invocation: %s\n' "$*" >&2; exit 1 ;;
esac
SH
chmod +x "$work/bin/"*
export PATH="$work/bin:$PATH"

case_number=0
new_case() {
	case_number=$((case_number + 1))
	export TEST_CASE="$work/$case_number"
	export HOME="$TEST_CASE/home"
	export XDG_STATE_HOME="$HOME/.local/state"
	export XDG_DATA_HOME="$HOME/.local/share"
	export XDG_CONFIG_HOME="$HOME/.config"
	export XDG_CACHE_HOME="$HOME/.cache"
	unset FAIL_DISCOVERY FAIL_CLONE NO_CONFIG NO_TASK GLOBAL_TASK FAIL_APPLY FAIL_STATUS
	unset EXESLIM_REFLECTION_URL
	mkdir -p "$HOME"
	: > "$TEST_CASE/events"
	cat > "$TEST_CASE/integrations.json" <<'JSON'
{"integrations":[{"name":"arbitrary-name","type":"github","comment":"personal exeslim-setup profile","help":"git clone https://github.int.exe.xyz/example/setup.git"}]}
JSON
	checkout="$XDG_DATA_HOME/exeslim/setup"
	marker="$XDG_STATE_HOME/exeslim/setup.json"
}

run_success() {
	if ! bash "$root/vm/exeslim-setup" > "$TEST_CASE/output" 2>&1; then
		cat "$TEST_CASE/output" >&2
		printf 'Unexpected failure in case %s\n' "$case_number" >&2
		exit 1
	fi
}

run_failure() {
	if bash "$root/vm/exeslim-setup" > "$TEST_CASE/output" 2>&1; then
		cat "$TEST_CASE/output" >&2
		printf 'Unexpected success in case %s\n' "$case_number" >&2
		exit 1
	fi
}

assert_no_event() {
	if grep -Fxq "$1" "$TEST_CASE/events"; then
		printf 'Unexpected event %s in case %s\n' "$1" "$case_number" >&2
		exit 1
	fi
}

pass() {
	printf 'PASS: %s\n' "$1"
}

new_case
run_success
grep -Fxq apply "$TEST_CASE/events"
jq -e '.version == 1 and .repository == "https://github.int.exe.xyz/example/setup.git" and .revision == "1111111111111111111111111111111111111111"' "$marker" >/dev/null
[[ $(stat -c %a "$marker") == 600 ]]
[[ $(stat -c %a "$(dirname "$marker")") == 700 ]]
pass 'marker substring and arbitrary repository; private completion record'

: > "$TEST_CASE/events"
export FAIL_DISCOVERY=1
run_success
[[ ! -s "$TEST_CASE/events" ]]
pass 'completed setup skips discovery and execution on later runs'

new_case
printf '{"integrations":[]}\n' > "$TEST_CASE/integrations.json"
run_success
assert_no_event clone
[[ ! -e "$marker" ]]
pass 'no integration is a successful skip without a marker'

new_case
printf '{"integrations":[{"type":"llm","comment":"exeslim-setup"},{"type":"github","comment":"dotfiles"}]}\n' > "$TEST_CASE/integrations.json"
run_success
assert_no_event clone
pass 'other integration types and markers are ignored'

new_case
jq '.integrations += .integrations' "$TEST_CASE/integrations.json" > "$TEST_CASE/multiple.json"
mv "$TEST_CASE/multiple.json" "$TEST_CASE/integrations.json"
run_failure
assert_no_event clone
pass 'ambiguous selection fails without running anything'

for payload in 'not json' '{}' '{"integrations":{}}' '{"integrations":[{"type":"github","comment":5}]}'; do
	new_case
	printf '%s\n' "$payload" > "$TEST_CASE/integrations.json"
	run_failure
	assert_no_event clone
done
pass 'malformed discovery responses fail'

new_case
export FAIL_DISCOVERY=1
run_failure
assert_no_event clone
[[ ! -e "$marker" ]]
pass 'network failure is not mistaken for an absent integration'

# shellcheck disable=SC2016
for help in \
	'git clone https://github.int.exe.xyz/example/setup.git; touch /tmp/unwanted' \
	'git clone https://github.int.exe.xyz/example/setup.git && echo bad' \
	'git clone $(echo bad)' \
	'git clone file:///tmp/repo' \
	'git clone ssh://git@example/repo' \
	'git clone https://secret@example/repo' \
	'git clone https://github.int.exe.xyz/../repo' \
	'git clone https://github.int.exe.xyz/example/..'; do
	new_case
	jq --arg help "$help" '.integrations[0].help = $help' "$TEST_CASE/integrations.json" > "$TEST_CASE/unsafe.json"
	mv "$TEST_CASE/unsafe.json" "$TEST_CASE/integrations.json"
	run_failure
	assert_no_event clone
done
pass 'help text is strictly parsed, never evaluated'

new_case
export FAIL_CLONE=1
run_failure
assert_no_event apply
[[ ! -e "$checkout" && ! -e "$marker" ]]
[[ -z "$(find "$XDG_DATA_HOME/exeslim" -name '.setup-clone.*' -print)" ]]
pass 'failed clone leaves no checkout, marker, or temporary directory'

new_case
export FAIL_APPLY=1
run_failure
[[ -d "$checkout/.git" && ! -e "$marker" ]]
unset FAIL_APPLY
: > "$TEST_CASE/events"
run_success
assert_no_event clone
grep -Fxq apply "$TEST_CASE/events"
[[ -f "$marker" ]]
pass 'failed apply retries the same checkout without pulling'

new_case
export FAIL_APPLY=1
run_failure
unset FAIL_APPLY
printf 'https://github.int.exe.xyz/other/repo.git\n' > "$checkout/.git/origin"
: > "$TEST_CASE/events"
run_failure
assert_no_event apply
pass 'existing checkout must match the selected repository'

new_case
export FAIL_APPLY=1
run_failure
unset FAIL_APPLY
touch "$checkout/.dirty"
: > "$TEST_CASE/events"
run_failure
assert_no_event apply
pass 'local changes are neither discarded nor executed automatically'

new_case
export FAIL_STATUS=1
run_failure
assert_no_event apply
[[ ! -e "$marker" ]]
pass 'failure to inspect the checkout prevents execution'

new_case
mkdir -p "$(dirname "$checkout")" "$TEST_CASE/unrelated"
ln -s "$TEST_CASE/unrelated" "$checkout"
run_failure
assert_no_event clone
pass 'symlink checkout is rejected'

new_case
mkdir -p "$checkout"
run_failure
assert_no_event clone
pass 'existing non-checkout directory is preserved'

for flag in NO_CONFIG NO_TASK GLOBAL_TASK; do
	new_case
	export "$flag=1"
	run_failure
	assert_no_event apply
	[[ ! -e "$marker" ]]
done
pass 'root mise.toml and its own apply task are required'

new_case
mkdir -p "$(dirname "$marker")"
printf 'corrupt\n' > "$marker"
run_failure
assert_no_event discover
pass 'corrupt completion state fails rather than reapplying setup'

new_case
mkdir -p "$(dirname "$marker")"
exec 8>"$(dirname "$marker")/setup.lock"
flock -n 8
run_success
[[ ! -s "$TEST_CASE/events" && ! -e "$marker" ]]
flock -u 8
exec 8>&-
pass 'concurrent execution is skipped'

printf 'All setup bootstrap tests passed.\n'
