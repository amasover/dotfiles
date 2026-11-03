emulate sh
. ~/.profile
emulate zsh

if [[ $OSTYPE == darwin* ]]; then
	# macOS (class work-mac): login shells and the GUI apps they start get mise's
	# shims; interactive shells add full activation, and Homebrew's prefix, in
	# .zshrc.
	if command -v mise >/dev/null; then
		eval "$(mise activate zsh --shims)"
	fi
elif [[ -z $DISPLAY && ${XDG_VTNR:-} == 1 ]]; then
	# Only on the first virtual console; an ssh or terminal-emulator login has
	# no XDG_VTNR, which the old `[ ... -eq 1 ]` test reported as an error.
	startx
fi
