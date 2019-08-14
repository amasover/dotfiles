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

# my monitor configurations
# replace with your own (based on the output above)

work_desktop="DVI-I-1 "
# work_desktop="DVI-I-1 DP-1 DVI-D-0 "
work_laptop="VGA-1 "
nav_work_laptop="*eDP-1 "
home_desktop="HDMI-0 DP-0 "
work_two_screens="VGA-1 VGA-2 "
work_three_screens="*eDP-1 DP-1 DP-2 "
home_laptop="VGA-1 VGA-2~1 VGA-2~2 VGA-2~3 "
home_four_screens="VGA-1 VGA-2 VGA-3 VGA-4 "
home_4k="DP-0 "
home_4k_two="DP-2 DP-3 "
home_4k_three="DP-3~1 DP-3~2 DP-2 "

function export_monitor_vars() {
    export MONITOR_MAIN=$1
    export MONITOR_RIGHT=$2
    export MONITOR_LEFT=$3
    export MONITOR_EXTRA=$4
}

function set_monitor_vars() {
    case "${active_monitors}" in
        $work_desktop )
            # export_monitor_vars "DVI-I-1" "DVI-D-0" "DP-1" #"DVI-I-1" ""  "" #"DVI-D-0"
            export_monitor_vars "" "DVI-I-1" "" #""  "" #"DVI-D-0"
            mode="work"
            ;;
        $nav_work_laptop )
            export_monitor_vars "eDP-1" "" ""
            mode="nav work laptop"
            ;;
        $work_laptop )
            export_monitor_vars "" "VGA-1" ""
            mode="work laptop"
            ;;
        $work_two_screens )
            export_monitor_vars "VGA-1" "VGA-2" ""
            mode="work two screens"
            ;;
        $work_three_screens )
            export_monitor_vars "DP-2" "" "DP-1" "eDP-1"
            mode="work three screens"
            ;;
        $home_desktop )
            export_monitor_vars "DP-4" "DVI-D-0" "HDMI-0"
            # export_monitor_vars "" "DP-4" "DVI-D-0"
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
        $home_4k )
            export_monitor_vars "DP-0"
            mode="home 4k"
            ;;
        $home_4k_two )
            export_monitor_vars "DP-2" "DP-3"
            mode="home 4k divided by two"
            ;;
        $home_4k_three )
            export_monitor_vars "DP-2" "DP-3~1" "" "DP-3~2"
            mode="home 4k divided by three"
            ;;
        * )
            notify-send "Polybar" "Monitor configuration not recognized. See ~/.config/polybar/launch.sh for details"
            notify-send "Polybar" "$(xrandr --listactivemonitors)"
            ;;
    esac
}

set_monitor_vars
notify-send "Polybar" "Bars initialized on ${mode} monitors."

killall -q polybar

while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done
# TODO set this theme somewhere else, probably via dot?
if [[ -z $polybar_theme ]]; then

    i3-msg gaps top all set 10
    export polybar_theme=$HOME/.config/polybar/themes/nord-arrow/config
fi

polybar -r main &
polybar -r right &
polybar -r left &
polybar -r extra &
polybar -r main.bottom &
polybar -r left.bottom &

echo "Bars launched..."
