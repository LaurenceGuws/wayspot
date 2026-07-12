#!/usr/bin/env bash

# Register the canonical Wayspot completion entrypoint without rebuilding Cmd meaning in Bash.

_WAYSPOT_COMPLETION_MAX_WORDS=16
_WAYSPOT_COMPLETION_MAX_LINE_CHARS=4096
_WAYSPOT_COMPLETION_MAX_WORD_CHARS=256

_wayspot_completion_unquote() {
    local value=$1
    local escaped="'\\''"
    local result=

    [[ ${value:0:1} == "'" && ${value: -1} == "'" ]] || return 1
    value=${value:1:${#value}-2}
    while [[ $value == *"$escaped"* ]]; do
        result+="${value%%"$escaped"*}"
        result+="'"
        value=${value#*"$escaped"}
    done
    result+="$value"
    REPLY=$result
}

_wayspot_complete() {
    COMPREPLY=()
    local line=${COMP_LINE-}
    local point_raw=${COMP_POINT-}
    local cword_raw=${COMP_CWORD-}
    local point
    local cword
    local word_count=0
    local line_prefix
    local current
    local first
    local second
    local char_after_cursor
    local binary=${WAYSPOT_BIN:-wayspot}
    local -a command=("$binary" complete bash)
    local index
    local record

    if [[ -n ${COMP_WORDS+x} ]]; then word_count=${#COMP_WORDS[@]}; fi
    ((${#line} <= _WAYSPOT_COMPLETION_MAX_LINE_CHARS)) || return 0
    ((word_count > 0 && word_count <= _WAYSPOT_COMPLETION_MAX_WORDS)) || return 0
    [[ $cword_raw =~ ^[0-9]+$ ]] || return 0
    ((${#cword_raw} <= 3)) || return 0
    while (( ${#cword_raw} > 1 )) && [[ ${cword_raw:0:1} == 0 ]]; do cword_raw=${cword_raw:1}; done
    cword=$cword_raw
    ((cword > 0 && cword < word_count && cword < _WAYSPOT_COMPLETION_MAX_WORDS)) || return 0

    if [[ -z ${COMP_POINT+x} ]]; then
        point=${#line}
    else
        [[ $point_raw =~ ^[0-9]+$ ]] || return 0
        ((${#point_raw} <= 4)) || return 0
        while (( ${#point_raw} > 1 )) && [[ ${point_raw:0:1} == 0 ]]; do point_raw=${point_raw:1}; done
        point=$point_raw
    fi
    ((point <= ${#line})) || return 0
    # COMP_WORDS contains the complete token. Reject a middle cursor rather
    # than guessing Bash's quoting and word-break rules from COMP_LINE.
    if ((point < ${#line})); then
        char_after_cursor=${line:point:1}
        [[ $char_after_cursor == " " || $char_after_cursor == $'\t' ]] || return 0
    fi

    for ((index = 0; index < word_count; index += 1)); do
        ((${#COMP_WORDS[index]} <= _WAYSPOT_COMPLETION_MAX_WORD_CHARS)) || return 0
    done

    current=${COMP_WORDS[cword]-}
    first=${COMP_WORDS[1]-}
    line_prefix=${line:0:point}
    if [[ $line_prefix == *" " ]]; then current=; fi

    if ((cword == 1)); then
        command+=(mode "/$current")
    elif ((cword == 2)); then
        case $first in
        apps) command+=(app "/apps $current") ;;
        notifications) command+=(sub_cmd "/notifications $current") ;;
        wallpaper) command+=(sub_cmd "/wallpapers $current") ;;
        sunglasses) command+=(sub_cmd "/sunglasses $current") ;;
        *) return 0 ;;
        esac
    elif ((cword == 3)) && [[ $first == sunglasses ]]; then
        second=${COMP_WORDS[2]-}
        case $second in
        dim | filter | image) command+=(operation "/sunglasses $second $current") ;;
        *) return 0 ;;
        esac
    else
        return 0
    fi

    COMPREPLY=()
    while IFS= read -r record; do
        _wayspot_completion_unquote "$record" || continue
        COMPREPLY+=("$REPLY")
    done < <("${command[@]}")
}

complete -F _wayspot_complete wayspot
