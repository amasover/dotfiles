#!/usr/bin/env bash
# rofi picker for polybar themes (bound to $mod+Shift+c in i3 config).
# Persists the choice so autorandr-triggered relaunches keep it — launch.sh
# reads the state file — then relaunches the bars.

themes_dir="$HOME/.config/polybar/themes"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/polybar"
rofi_theme="${1:-$HOME/.config/rofi/config.rasi}"

# A theme is usable only if its config defines the bars launch.sh launches;
# launch.sh passes the config via -c, so an incompatible one means no bars.
theme_config() {
    local f
    for f in "$1/config.ini" "$1/config"; do
        [[ -f $f ]] && grep -q '^\[bar/main\]' "$f" && { printf '%s\n' "$f"; return 0; }
    done
    return 1
}

options=""
for d in "$themes_dir"/*/; do
    name=$(basename "$d")
    [[ $name == *global* ]] && continue
    theme_config "${d%/}" >/dev/null && options+="${name}"$'\n'
done

theme=$(printf '%s' "$options" | rofi -dmenu -config "$rofi_theme")
# don't kill polybar if no theme was chosen
[[ -z $theme ]] && exit 1

cfg=$(theme_config "$themes_dir/$theme") || exit 1
mkdir -p "$state_dir"
printf '%s\n' "$cfg" >"$state_dir/theme"
exec "$HOME/.config/polybar/launch.sh"
