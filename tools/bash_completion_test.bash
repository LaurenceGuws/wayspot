#!/usr/bin/env bash
set -euo pipefail

wayspot=$(realpath "$1")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

"$wayspot" completion bash >"$work/completion.bash"
bash -n "$work/completion.bash"
source "$work/completion.bash"
[[ $(complete -p wayspot) == 'complete -F _wayspot_completion wayspot' ]]
cd "$work"

expect() {
    local expected=$1
    shift
    COMP_WORDS=("$@")
    COMP_CWORD=$((${#COMP_WORDS[@]} - 1))
    _wayspot_completion
    [[ $(printf '%s\n' "${COMPREPLY[@]}") == "$expected" ]]
}

expect 'apps' wayspot ap
expect $'apps\nnotifications\nwallpaper' wayspot ''
expect 'history' wayspot notifications h
expect 'rotate' wayspot wallpaper r

mkdir "$work/blue"
expect "$work/blue" wayspot wallpaper "$work/bl"

cat >"$work/wayspot" <<'EOF'
#!/usr/bin/env bash
[[ $1 == apps ]] || exit 2
printf '%s\n' 'Alpha Editor' 'Teams for Linux'
EOF
chmod +x "$work/wayspot"
PATH="$work:$PATH"
expect $'Alpha Editor\nTeams for Linux' wayspot apps ''

COMP_WORDS=(wayspot)
COMP_CWORD=9
COMPREPLY=(stale)
_wayspot_completion
((${#COMPREPLY[@]} == 0))
