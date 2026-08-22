#!/usr/bin/env bash
#
# polybar launcher (Story 5.5, #152)
#
# Roles, not layouts: MONITOR_MAIN / MONITOR_LEFT / MONITOR_EXTRA (plus the
# split-4K MONITOR_SPLIT_TOP/BOTTOM) tell the theme's bars where to sit.
# Role resolution:
#   1. the positional heuristic in tools/monitor-roles: primary → MAIN, the
#      leftmost monitor left of MAIN → LEFT, the next remaining → EXTRA;
#   2. a per-autorandr-profile override, ~/.config/polybar/layouts/<profile>.env
#      (profile from $AUTORANDR_CURRENT_PROFILE inside autorandr hooks, else
#      `autorandr --current`), merged ON TOP of the heuristic — it overrides or
#      clears only the roles it names (see layouts/example.env.sample). Write
#      one for any setup the heuristic can't infer, the virtual-split docking
#      layouts above all.
# Bars launch only when their role is assigned; a bare guest (Virtual-1)
# gets the MAIN bars with zero configuration.
#
# Theme: $polybar_theme env if set (one-shot override), else the choice
# persisted by polybar-theme-selector.sh, else the nord-arrow default. A
# config that doesn't define bar/main falls back to the default, loudly.
# The bar's top gap lives in i3 config (gaps top), not here.
#
# The pre-3.16 hardcoded layouts, kept for reference when writing 3.17's
# override files (the output names predate the modesetting-driver rename):
#   laptop:      "eDP1 "                          -> MAIN=eDP1
#   laptop_4k:   "*DP1-1 DP1-2~1 DP1-2~2 eDP1 "   -> MAIN=DP1-1 SPLIT_TOP=DP1-2~1 SPLIT_BOTTOM=DP1-2~2 LEFT=eDP1
#   home:        "*eDP1 DP1-1~1 DP1-1~2 DP1-2 "   -> MAIN=DP1-2 SPLIT_TOP=DP1-1~1 SPLIT_BOTTOM=DP1-1~2 LEFT=eDP1
#   three:       "*eDP-1 DP-1-1 DP-1-3 "          -> MAIN=eDP-1 SPLIT_TOP=DP-1-1 SPLIT_BOTTOM=DP-1-3
#   displaylink: "*DP1-1 eDP1 DP1-3 "             -> MAIN=eDP1 SPLIT_TOP=DVI-I-1-1
#   dragon:      "eDP1 DP1 "                      -> MAIN=eDP1 SPLIT_TOP=DP1

# Serialize concurrent runs: i3's exec_always and the autorandr postswitch
# hook can both fire at login, and unlocked their killall/launch phases
# interleave into duplicate or missing bars. Blocking (not flock -n): a
# queued run may carry newer topology, so the last writer must win.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/polybar-launch.lock"
flock 9

log_dir="${XDG_CACHE_HOME:-$HOME/.cache}/polybar"
mkdir -p "$log_dir"
log="$log_dir/polybar.log"
# .$$ keeps two same-second runs from clobbering each other's archive
[[ -s $log ]] && mv "$log" "$log.$(date +%Y%m%d-%H%M%S).$$"
# shellcheck disable=SC2012  # filenames are our own timestamps, ls -t is fine
ls -1t "$log_dir"/polybar.log.* 2>/dev/null | tail -n +6 | xargs -r rm -f

# Role-resolution warnings used to die on a discarded stderr; put every one
# in the log and on the desktop. 9>&- so the notify can't hold the launch
# lock; backgrounded so a stalled notification daemon can't block a switch.
warn() {
    printf 'polybar-launch: %s\n' "$*" | tee -a "$log" >&2
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "Polybar" "$*" 9>&- &
    fi
}

tools="$HOME/.local/bin/tools"
layout_dir="$HOME/.config/polybar/layouts"

profile="${AUTORANDR_CURRENT_PROFILE-}"
# Outside autorandr hooks, asking autorandr costs ~150ms and is only worth it
# when an override file could exist; --current can also list several profiles
# matching the current fingerprint, so the pick is surfaced when ambiguous.
if [[ -z $profile ]] && compgen -G "$layout_dir/*.env" >/dev/null; then
    mapfile -t matched < <(autorandr --current 2>/dev/null)
    profile="${matched[0]-}"
    ((${#matched[@]} > 1)) && warn "autorandr matches several profiles (${matched[*]}); using ${profile}"
fi
layout_env="$layout_dir/${profile}.env"

unset MONITOR_MAIN MONITOR_LEFT MONITOR_EXTRA MONITOR_SPLIT_TOP MONITOR_SPLIT_BOTTOM
roles_err=$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/polybar-roles-err.XXXXXX")
set -a  # auto-export whatever the role sources assign
eval "$("$tools/monitor-roles" 2>>"$roles_err")"
[[ -n $profile && -f $layout_env ]] && eval "$("$tools/monitor-roles" merge-env "$layout_env" 2>>"$roles_err")"
set +a
while IFS= read -r line; do warn "$line"; done <"$roles_err"
rm -f "$roles_err"

if [[ -n $profile && -f $layout_env ]]; then
    mode="profile ${profile}"
else
    mode="auto: ${MONITOR_MAIN}${MONITOR_LEFT:+ left=${MONITOR_LEFT}}${MONITOR_EXTRA:+ extra=${MONITOR_EXTRA}}"
fi

if [[ -z ${MONITOR_MAIN:-} ]]; then
    warn "no MONITOR_MAIN resolved (${mode}); leaving existing bars untouched"
    exit 1
fi

theme_state="${XDG_STATE_HOME:-$HOME/.local/state}/polybar/theme"
default_theme="$HOME/.config/polybar/themes/nord-arrow/config.ini"
[[ -z ${polybar_theme:-} && -f $theme_state ]] && polybar_theme=$(<"$theme_state")
polybar_theme="${polybar_theme:-$default_theme}"
if [[ ! -f $polybar_theme ]] || ! grep -q '^\[bar/main\]' "$polybar_theme"; then
    warn "theme config unusable (${polybar_theme:-empty}); using default"
    polybar_theme="$default_theme"
fi
export polybar_theme

killall -q -w polybar

# -c is load-bearing: no config.ini lives in ~/.config/polybar, so without an
# explicit config polybar silently falls back to its built-in example bar.
# 9>&- drops the launch lock in the bars, which outlive this script.
launch() {
    if ! grep -q "^\[bar/$1\]" "$polybar_theme"; then
        warn "theme has no [bar/$1]; skipping"
        return
    fi
    polybar -r -l warning -c "$polybar_theme" "$1" >>"$log" 2>&1 9>&- &
}
launch main
launch main-bottom
[[ -n ${MONITOR_LEFT:-} ]]         && launch left
[[ -n ${MONITOR_EXTRA:-} ]]        && launch extra
[[ -n ${MONITOR_SPLIT_TOP:-} ]]    && launch split-one
[[ -n ${MONITOR_SPLIT_BOTTOM:-} ]] && launch split-two

if command -v notify-send >/dev/null 2>&1; then
    notify-send "Polybar" "Bars up (${mode})" 9>&- &
fi
echo "Bars launched (${mode})"
