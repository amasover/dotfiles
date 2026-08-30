#!/usr/bin/env bash

# returns true if current times seconds field
# is divisible by 3
function delay() {
    f=$(date +"%S")
    j=$((10#$f % 3))

    if ((10#$j == 0)); then
        # notify-send $f "$j loading"
        echo true
    else
        # notify-send $f "$j not"
        echo false
    fi
}

###################
## COLOR PALETTE ##
###################

# Nord colors used by this block.
nord0="#2E3440"
nord1="#3B4252"
nord11="#BF616A"
nord13="#EBCB8B"
nord14="#A3BE8C"

yadm fetch >/dev/null 2>&1

staged=$(yadm diff --cached --numstat | wc -l)
modified=$(yadm ls-files -m | wc -l)
# shows how many commits ahead and behind local main is from origin
ahead_behind_count=$(yadm rev-list --left-right --count main...origin/main)
read -r ahead behind <<<"$ahead_behind_count"

ahead_icon=
behind_icon=
yadm_icon=

no=
yes=
modified_icon=
staged_icon=
commits_prompt="  $yadm_icon $behind $behind_icon $ahead $ahead_icon "

# TODO: fix this, not sure how to hand parameters to this script from polybar
if [[ ${1:-} == true ]]; then
    arrow=" "
else
    arrow=""
fi

function color {
    echo "%{B${1}}%{F${2}}${3}%{B-}%{F-}"
}

if [[ "$behind" -gt 0 ]]; then
    fg=$nord11
    commits_prompt=$(color "${nord11}" "${nord1}" "${commits_prompt}")
elif [[ "$ahead" -gt 0 ]]; then
    fg=$nord13
    commits_prompt=$(color "${nord13}" "${nord1}" "${commits_prompt}")
else
    fg=$nord14
    commits_prompt=$(color "${nord14}" "${nord1}" "${commits_prompt}")
fi

if [[ $staged != "0" || $modified != "0" ]]; then

    bg=$nord13
    staged_prompt=$(color "${nord13}" "${nord1}" " $staged_icon $staged $modified_icon $modified  $no ")$(color "${nord0}" "${nord13}" "$arrow")
else
    bg=$nord14
    staged_prompt=$(color "${nord14}" "${nord1}" " $staged_icon $staged $modified_icon $modified  $yes ")$(color "${nord0}" "${nord14}" "$arrow")
fi

if [[ $bg == "$fg" ]]; then
    separator=$(color "${bg}" "${nord1}" "")
else
    separator=$(color "${bg}" "${fg}" "$arrow")
fi

printf '%s\n' "${commits_prompt}${separator}${staged_prompt}"
