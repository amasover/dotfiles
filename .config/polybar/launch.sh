#!/usr/bin/env bash

# description:
#   This script is useful for auto detection of multiple monitor layouts

#   This script inspects names of monitors connected to computer
#   and assigns them to right, left, and main monitor environment
#   variables, so that Polybar can properly put it's left/right/middle
#   bars in the right place.

#   If your monitors are in a different configuration, edit the
#   strings in the case statement.

# get list of connected monitors, space separated
#active_monitors=$(xrandr -q | grep " connected" | awk "{print $"${1:-1}"}" ORS=" ")
active_monitors=$(xrandr --listactivemonitors | tail -n +2 | awk '{print $2}' ORS=" " | sed 's/+//g')
test=echo $(echo $active_monitors | sed 's/*//g')
echo "$test"

# my monitor configurations
# replace with your own (based on the output above)

laptop="eDP1 "
laptop_star="*eDP1 "
laptop_4k="*DP1-1 DP1-2~1 DP1-2~2 eDP1 "
three="eDP1 DP1-1 DP1-3 "
displaylink="*DP1-1 eDP1 DP1-3 "
dragon="eDP1 DP1 "
home="*eDP1 DP1-1~1 DP1-1~2 DP1-2 "

echo "active monitors is $active_monitors"
echo "laptop 4k is $laptop_4k"

function export_monitor_vars() {
    export MONITOR_MAIN=$1
    export MONITOR_SPLIT_TOP=$2 #one
    export MONITOR_SPLIT_BOTTOM=$3 #two
    export MONITOR_LEFT=$4
    export MONITOR_EXTRA=$5
    echo "monitor split top $MONITOR_SPLIT_TOP"
    echo "monitor split bottom $MONITOR_SPLIT_BOTTOM"
}

function set_monitor_vars() {
    case "${active_monitors}" in
        "$laptop" )
            export_monitor_vars "eDP1" "" "" ""
            mode="just laptop screen"
            ;;
        "$laptop_star" )
            export_monitor_vars "eDP1" "" "" ""
            mode="just laptop screen(star)"
            ;;
        "$laptop_4k" )
            export_monitor_vars "DP1-1" "DP1-2~1" "DP1-2~2" "eDP1" ""
            mode="4k split with laptop monitor"
            ;;
        "$home" )
            export_monitor_vars "DP1-2" "DP1-1~1" "DP1-1~2" "eDP1" ""
            mode="4k split with laptop monitor (home)"
            ;;
        "$three" )
            export_monitor_vars "eDP1" "DP1-1" "DP1-3" "" ""
            mode="three"
            ;;
        "$displaylink" )
            export_monitor_vars "eDP1" "DVI-I-1-1" "" "" ""
            mode="displaylink"
            ;;
        "$dragon" )
            export_monitor_vars "eDP1" "DP1" "" "" ""
            mode="dragon"
            ;;
        * )
            notify-send "Polybar" "Monitor configuration not recognized. See ~/.config/polybar/launch.sh for details"
            notify-send "Polybar" "$(xrandr --listactivemonitors)"
            ;;
    esac
}

set_monitor_vars
notify-send "Polybar" "Bars initialized on ${mode} monitors."

killall -q -w polybar

echo killed old polybar

while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done

echo done
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
ls -1t "$log_dir"/polybar.log.* 2>/dev/null | tail -n +6 | xargs -r rm -f

polybar -r -l warning main        >>"$log" 2>&1 &
#polybar -r right &
polybar -r -l warning left        >>"$log" 2>&1 &
polybar -r -l warning extra       >>"$log" 2>&1 &
polybar -r -l warning main-bottom >>"$log" 2>&1 &
polybar -r -l warning split-one   >>"$log" 2>&1 &
polybar -r -l warning split-two   >>"$log" 2>&1 &
#polybar -r left-bottom &

echo "Bars launched..."
