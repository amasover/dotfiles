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
	# A plain `omp` runs omp-mode claude's roles (docs/decision-mac-host.md).
	# Here rather than in .zshrc so login shells that are not interactive, such
	# as `zsh -l -c omp`, get it too; interactive shells inherit it. omp-mode
	# appends its own mode after this overlay, and the last one wins.
	if [[ -z ${PI_CONFIG_FILES:-} && -r $HOME/.omp/agent/modes/claude.yml ]]; then
		export PI_CONFIG_FILES=$HOME/.omp/agent/modes/claude.yml
	fi
elif [ -z "$DISPLAY" -a $XDG_VTNR -eq 1 ]; then
	startx
fi
