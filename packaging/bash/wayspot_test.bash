#!/usr/bin/env bash

set -euo pipefail

repo_root=${WAYSPOT_ROOT:-$PWD}
WAYSPOT_BIN=${WAYSPOT_BIN:-"$repo_root/zig-out/bin/wayspot"}
export WAYSPOT_BIN

source "$repo_root/packaging/bash/wayspot.bash"

complete_line() {
    local line=$1
    shift
    COMP_LINE=$line
    COMP_POINT=${#line}
    COMP_WORDS=("$@")
    COMP_CWORD=$#
    (( COMP_CWORD -= 1 ))
    _wayspot_complete
}

expect_exact() {
    local label=$1
    local line=$2
    shift 2
    local -a expected=()
    while (( $# > 0 )) && [[ $1 != -- ]]; do
        expected+=("$1")
        shift
    done
    [[ ${1-} == -- ]] || return 1
    shift
    local -a words=("$@")

    complete_line "$line" "${words[@]}"
    [[ ${#COMPREPLY[@]} -eq ${#expected[@]} ]] || {
        printf '%s: expected %d replies, got %d\n' "$label" "${#expected[@]}" "${#COMPREPLY[@]}" >&2
        return 1
    }
    local index
    for ((index = 0; index < ${#expected[@]}; index += 1)); do
        [[ ${COMPREPLY[index]} == "${expected[index]}" ]] || {
            printf '%s: reply %d mismatch: %q != %q\n' "$label" "$index" "${COMPREPLY[index]}" "${expected[index]}" >&2
            return 1
        }
    done
}

expect_exact "top-level mode" "wayspot " apps notifications wallpaper sunglasses -- wayspot ""
expect_exact "sunglasses subcommand" "wayspot sunglasses " restart apply reconcile dim filter image -- wayspot sunglasses ""
expect_exact "sunglasses operation" "wayspot sunglasses dim " set on off -- wayspot sunglasses dim ""

complete_line "wayspot apps " wayspot apps ""
(( ${#COMPREPLY[@]} > 0 ))
for reply in "${COMPREPLY[@]}"; do
    [[ $reply != "wayspot apps"* ]]
    [[ $reply != notification-history:* ]]
done

COMP_LINE="wayspot "
COMP_POINT=4097
COMP_WORDS=(wayspot "")
COMP_CWORD=1
_wayspot_complete
(( ${#COMPREPLY[@]} == 0 ))

COMP_LINE="wayspot "
COMP_POINT=7
COMP_WORDS=(wayspot "")
COMP_CWORD=99
_wayspot_complete
(( ${#COMPREPLY[@]} == 0 ))

COMP_LINE="wayspot sunglasses"
COMP_POINT=10
COMP_WORDS=(wayspot sunglasses)
COMP_CWORD=1
_wayspot_complete
(( ${#COMPREPLY[@]} == 0 ))

printf '%s\n' 'Bash completion COMPREPLY assertions passed.'
