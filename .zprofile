emulate sh
. ~/.profile
emulate zsh

if [[ $OSTYPE == darwin* ]]; then
	# macOS (class work-mac): login shells and the GUI apps they start get mise's
	# shims; interactive shells add full activation in .zshrc. Homebrew's prefix
	# goes first so its tools win over the older system ones.
	[[ -d /opt/homebrew/bin ]] && export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
	if command -v mise >/dev/null; then
		eval "$(mise activate zsh --shims)"
	fi
elif [ -z "$DISPLAY" -a $XDG_VTNR -eq 1 ]; then
	startx
fi
