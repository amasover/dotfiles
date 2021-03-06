# If you come from bash you might have to camasoverge your $PATH.
 export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

# auto load .nvmrc and apply when cd into a directory that has an .nvmrc
# this must be loaded before the zsh-nvm plugin
export NVM_AUTO_USE=true


# Set name of the theme to load. Optionally, if you set this to "random"
# it'll load a random theme each time that oh-my-zsh is loaded.
# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
ZSH_THEME="agnoster"
# ZSH_THEME="lambda-mod"
# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion. Case
# sensitive completion must be off. _ and - will be intercamasovergeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# The optional three formats: "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder tamasover $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
    git
    docker
    vi-mode
    archlinux
    zsh-autosuggestions
    # custom plugins #
    # https://github.com/lukechilds/zsh-nvm
    zsh-nvm)

source $ZSH/oh-my-zsh.sh
source ~/.zsh_plugins.sh

#############################
#     USER CONFIGURATION    #
#############################

# Export these user specific environment variables in your ~/.zshenv
# in order for these aliases to work:
    # export GITHUB_ACCOUNT=
    # export BITBUCKET_ACCOUNT=
    # export NPM_TOKEN=

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export ARCHFLAGS="-arch x86_64"
  export EDITOR='vim'
fi

# Compilation flags
export ARCHFLAGS="-arch x86_64"

function pe() {
    echo "ERROR: $1" >&2
    exit 1
}

function edit-config {
    config_file=~/.config/${1}/config
    if [[ -f "${config_file}" ]]; then
        vim $config_file
    else
        echo "${config_file}"
        echo "no config file found for ${1}" >&2
    fi
}

function grep_i3_keybinds {
    cat "${HOME}"/.config/i3/config | awk '/^bindsym/ { print }' | grep "\$mod+$1 "
}

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
alias gi3=grep_i3_keybinds
alias h="cd ~"
alias ec="edit-config"
alias ecp="ec polybar"
alias ez="vim ~/.zshrc"
alias vz="vim ~/.zshrc"
alias sz="source ~/.zshrc"
alias gs="git status"
alias gau="git add -u" # git add unstaged only
alias gaa="git add -A" # git add all
alias gcm="git commit -m"
alias gca="git commit --amend"
alias gb="git branch"
alias gd="git diff"
alias gds="git diff --staged"
alias gcb="git checkout -b"
alias gc="git commit --verbose"
alias gbl="git branch -l"
alias gp="git push"
alias gpf="git push --force-with-lease"
alias gpp="quick-git-check-in"
alias glv="git log | vim -"
alias gl="git log"
# git push and set upstream to current branch
function push_upstream () {
    git push -u origin $(git branch | grep "*" | awk -F " " '{print $NF}')
}
alias gpu=push_upstream
alias sctl="sudo systemctl"
alias pbcopy="xclip -selection clipboard"
alias pbpaste="xclip -selection clipboard -o"
alias restart="shutdown -r now"
## reload xresources
alias xrl="xrdb ~/.Xresources"
alias nr="node run.js"
alias kl="kubectl"
alias pacman="sudo pacman"
alias x="chmod +x"

alias y="yadm"
alias ya="yadm add"
alias yaa="yadm add -u" # add only unstaged files
alias yau="yadm add -u" # add only unstaged files
function yadm_add_tool () {
   yadm add ~/.local/bin/tools/$1
}
alias yat=yadm_add_tool
alias yc="yadm commit --verbose"
alias yca="yadm commit --amend"
alias ycm="yadm commit -m"
alias yp="yadm push"
alias ypf="yadm push -f"
alias ys="yadm status"
alias ye="yadm encrypt"
alias yd="yadm diff"
alias yds="yadm diff --staged"
alias yaf="yadm add ~/.yadm/files.gpg"
alias yafp="yadm add ~/.yadm/files.gpg ~/.yadm/encrypt && yadm commit -m 'encrypt' && yadm push"
alias token=~/.ssh/token

alias setup-run="bash ~/.local/bin/setup/install"
alias setup-edit="vim ~/.local/bin/setup/install"
alias update="zsh ~/.local/bin/setup/update"
alias tools="cd ~/.local/bin/tools/ && ll"

alias npmis="npm install --save"
alias npmisd="npm install --save-dev"

alias cat="ccat"
alias ls="exa"
alias ll="exa -la"
alias gimme="sudo pacman -S"
alias bgf="~/.fehbg"
alias bgn="update_background"

alias c="cd ~/code && ll"
alias cgbb="cd ~/code/go/src/bitbucket.org/wtsdevops && ll"
alias cggh="cd $GOPATH/src/github.com/$GITHUB_ACCOUNT && ll"
alias vssh="vim ~/.ssh/config"
alias lssh="ls ~/.ssh"
alias rmrf="rm -rfi"
alias update-emacs="cd $HOME/.emacs.d && git pull --rebase && cd $HOME"
alias ns="new_script --path . --name"
alias nt="new_script --name"
alias ranger='ranger --choosedir=$HOME/.rangerdir; LASTDIR=`cat $HOME/.rangerdir`; cd "$LASTDIR"'
alias v='vim'

update_golang() {
    # update golang pacman package
    echo "\nUpdating golang...\n"
    sudo pacman -Sy --needed go
    echo "\nUpdating golang packages...\n"
    go get -u all
}

update_pacman_mirrorlist() {
    sudo reflector --verbose --protocol https --age 8 --sort rate --save /etc/pacman.d/mirrorlist
}
alias yaf="yadm add ~/.yadm/files.gpg"

# leave this function with the _ prefix and aliased below without
# the prefix. Without them zsh errors on sourcing because grep
# is referencing an alias in this function. ( my grep is grep plus some
# formatting flags)
_sshg() {
    cat ~/.ssh/config | grep "Host $1"
}
# quickly grep ssh hosts from config file
alias grepssh=_sshg

#switch between different AWS accounts
alias work-mode="switch-aws-creds.sh work"
alias other-mode="switch-aws-creds.sh other"
alias check-mode="aws s3 ls"

# leave this function with the _ prefix and aliased below without
# the prefix. Without them zsh errors on sourcing because grep
# is referencing an alias in this function. ( my grep is grep plus some
# formatting flags)
_sshg() {
    cat ~/.ssh/config | grep "Host $1"
}
# quickly grep ssh hosts from config file
alias grepssh=_sshg
alias dotfiles="cd ~/.config/dotfiles/"
alias dot-src="cd $GOPATH/src/github.com/patrick-motard/dot"
alias copy-monitors='xrandr -q | grep " connected" | awk "{print $"${1:-1}"}" ORS=" " | pbcopy'


## CUSTOM KEY BINDINGS ##
## zsh vi-mode settings
# remaps ESC to fd
bindkey -M viins 'fd' vi-cmd-mode
#bindkey 'lk' autosuggest-accept

export PATH=~/.local/bin/work:$PATH
export PATH=~/.local/bin:$PATH
export PATH=~/.local/bin/tools:$PATH
export PATH=~/.local/bin/wts-encryption:$PATH
export PATH=/opt/idea-IC-171.4424.56/bin:$PATH
export PATH=/usr/share/intellijidea-ce/bin:$PATH

## NPM TOKEN SETUP
export NPM_TOKEN=$NPM_TOKEN

# ansible playbooks
export ANSIBLE_PLAYBOOKS_DIR=~/code/ansible-playbooks

#switch between different AWS accounts
alias work-mode="switch-aws-creds.sh work"
alias other-mode="switch-aws-creds.sh other"
alias check-mode="aws s3 ls"

alias dotfiles="cd ~/.config/dotfiles/"
alias dot-src="cd $GOPATH/src/github.com/patrick-motard/dot"
alias copy-monitors='xrandr -q | grep " connected" | awk "{print $"${1:-1}"}" ORS=" " | pbcopy'


## CUSTOM KEY BINDINGS ##
## zsh vi-mode settings
# remaps ESC to fd

#use vim for manpages
export MANPAGER="/bin/sh -c \"col -b | vim -c 'set ft=man ts=8 nomod nolist nonu noma' -\""

# Use vim mode
bindkey -v
bindkey '^R' history-incremental-pattern-search-backward
# why are things strange sometimes?
bindkey "\e[3~" delete-char
bindkey '^J' self-insert-unmeta

## Kubernetes
command -v kubectl >/dev/null 2>&1
if [[ $? == 0 ]]; then
    source <(kubectl completion zsh)
fi

## Azure
if [[ -f /home/$USER/lib/azure-cli/az.completion ]]; then
    autoload bashcompinit && bashcompinit
    source /home/$USER/lib/azure-cli/az.completion
fi

## VIM POWERLINE
if [[ -r ~/.local/lib/python2.7/site-packages/powerline/bindings/zsh/powerline.zsh ]]; then
    source ~/.local/lib/python2.7/site-packages/powerline/bindings/zsh/powerline.zsh
fi

export DOTNET_ROOT="/opt/dotnet"
