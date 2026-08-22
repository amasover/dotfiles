#!/usr/bin/env bash
#
# polybar launcher (Story 5.5, #152)
#
# Roles, not layouts: MONITOR_MAIN / MONITOR_LEFT / MONITOR_EXTRA (plus the
# split-4K MONITOR_SPLIT_TOP/BOTTOM) tell the theme's bars where to sit.
# Role resolution order:
#   1. a per-autorandr-profile override, ~/.config/polybar/layouts/<profile>.env
#      (profile from $AUTORANDR_CURRENT_PROFILE inside autorandr hooks, else
#      `autorandr --current`) — write one for any setup the heuristic can't
#      infer, the virtual-split docking layouts above all;
#   2. the positional heuristic in tools/monitor-roles: primary → MAIN, the
#      leftmost monitor left of MAIN → LEFT, the next remaining → EXTRA.
# Bars launch only when their role is assigned; a bare guest (Virtual-1)
# gets the MAIN bars with zero configuration.
#
# The pre-3.16 hardcoded layouts, kept for reference when writing 3.17's
# override files (the output names predate the modesetting-driver rename):
#   laptop:      "eDP1 "                          -> MAIN=eDP1
#   laptop_4k:   "*DP1-1 DP1-2~1 DP1-2~2 eDP1 "   -> MAIN=DP1-1 SPLIT_TOP=DP1-2~1 SPLIT_BOTTOM=DP1-2~2 LEFT=eDP1
#   home:        "*eDP1 DP1-1~1 DP1-1~2 DP1-2 "   -> MAIN=DP1-2 SPLIT_TOP=DP1-1~1 SPLIT_BOTTOM=DP1-1~2 LEFT=eDP1
#   three:       "*eDP-1 DP-1-1 DP-1-3 "          -> MAIN=eDP-1 SPLIT_TOP=DP-1-1 SPLIT_BOTTOM=DP-1-3
#   displaylink: "*DP1-1 eDP1 DP1-3 "             -> MAIN=eDP1 SPLIT_TOP=DVI-I-1-1
#   dragon:      "eDP1 DP1 "                      -> MAIN=eDP1 SPLIT_TOP=DP1

unset MONITOR_MAIN MONITOR_LEFT MONITOR_EXTRA MONITOR_SPLIT_TOP MONITOR_SPLIT_BOTTOM

profile="${AUTORANDR_CURRENT_PROFILE:-$(autorandr --current 2>/dev/null | head -n1)}"
layout_env="$HOME/.config/polybar/layouts/${profile}.env"
if [[ -n "$profile" && -f "$layout_env" ]]; then
    # shellcheck source=/dev/null
    source "$layout_env"
    mode="profile ${profile}"
else
    eval "$("$HOME/.local/bin/tools/monitor-roles")"
    mode="auto: ${MONITOR_MAIN}${MONITOR_LEFT:+ left=${MONITOR_LEFT}}${MONITOR_EXTRA:+ extra=${MONITOR_EXTRA}}"
fi
export MONITOR_MAIN MONITOR_LEFT MONITOR_EXTRA MONITOR_SPLIT_TOP MONITOR_SPLIT_BOTTOM

killall -q -w polybar
while pgrep -u "$UID" -x polybar >/dev/null; do sleep 1; done

# TODO set this theme somewhere else, probably via dot?
if [[ -z $polybar_theme ]]; then
    i3-msg gaps top all set 10
    export polybar_theme=$HOME/.config/polybar/themes/nord-arrow/config.ini
fi

# Polybar logs, rotated (keep the last 5 launches), in ~/.cache/polybar/.
log_dir="${XDG_CACHE_HOME:-$HOME/.cache}/polybar"
mkdir -p "$log_dir"
log="$log_dir/polybar.log"
[[ -f $log ]] && mv "$log" "$log.$(date +%Y%m%d-%H%M%S)"
# shellcheck disable=SC2012  # filenames are our own timestamps, ls -t is fine
ls -1t "$log_dir"/polybar.log.* 2>/dev/null | tail -n +6 | xargs -r rm -f

# -c is load-bearing: no config.ini lives in ~/.config/polybar, so without an
# explicit config polybar silently falls back to its built-in example bar.
launch() { polybar -r -l warning -c "$polybar_theme" "$1" >>"$log" 2>&1 & }
launch main
launch main-bottom
[[ -n ${MONITOR_LEFT:-} ]]         && launch left
[[ -n ${MONITOR_EXTRA:-} ]]        && launch extra
[[ -n ${MONITOR_SPLIT_TOP:-} ]]    && launch split-one
[[ -n ${MONITOR_SPLIT_BOTTOM:-} ]] && launch split-two

command -v notify-send >/dev/null 2>&1 && notify-send "Polybar" "Bars up (${mode})"
echo "Bars launched (${mode})"
