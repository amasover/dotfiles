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
active_monitors=$(xrandr -q | grep " connected" | awk "{print $"${1:-1}"}" ORS=" ")

# my monitor configurations
# replace with your own (based on the output above)
work_desktop="DVI-I-1 DVI-D-0 "
work_laptop="VGA-1 "
home_desktop="HDMI-0 DP-0 "
work_two_screens="VGA-1 VGA-2 "
work_three_screens="VGA-1 VGA-2 VGA-3 "
home_laptop="VGA-1 VGA-2~1 VGA-2~2 VGA-2~3 "
home_four_screens="VGA-1 VGA-2 VGA-3 VGA-4 "

function export_monitor_vars() {
    export MONITOR_MAIN=$1
    export MONITOR_RIGHT=$2
    export MONITOR_LEFT=$3
    export MONITOR_EXTRA=$4
}

function set_monitor_vars() {
    case "${active_monitors}" in
        $work_desktop )
            export_monitor_vars "DVI-I-1" "DVI-D-0" ""
            mode="work"
            ;;
        $work_laptop )
            export_monitor_vars "VGA-1" "" ""
            mode="work laptop"
            ;;
        $work_two_screens )
            export_monitor_vars "VGA-1" "VGA-2" ""
            mode="work two screens"
            ;;
        $work_three_screens )
            export_monitor_vars "VGA-1" "VGA-2" "" "VGA-3"
            mode="work three screens"
            ;;
        $home_desktop )
            export_monitor_vars "DP-0" "" "HDMI-0"
            mode="home desktop"
            ;;
        $home_laptop )
            export_monitor_vars "VGA-2~1" "VGA-2~2" "VGA-1" "VGA-2~3"
            mode="home laptop"
            ;;
        $home_four_screens )
            export_monitor_vars "VGA-1" "VGA-2" "VGA-4" "VGA-3"
            mode="home four screens"
            ;;
        * )
            notify-send "Polybar" "Monitor configuration not recognized. See ~/.config/polybar/launch.sh for details"
            ;;
    esac
}

set_monitor_vars
notify-send "Polybar" "Bars initialized on ${mode} monitors."

killall -q polybar

while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done

polybar -r main &
polybar -r right &
polybar -r left &
polybar -r extra &
polybar -r main.bottom &

echo "Bars launched..."
