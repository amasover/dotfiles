#!/usr/bin/env bash

case "$1" in
    --toggle)
        if [ "$(pgrep dropbox)" ]; then
            pkill -f dropbox
        else
            dropbox &
        fi
        ;;
    *)
        if [ "$(pgrep dropbox)" ]; then
            echo " %{F#A3BE8C}%{F-} "
        else

            echo " %{F#5E81AC}%{F-} "
        fi
        ;;
esac
