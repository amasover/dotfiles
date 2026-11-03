# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh
pager() {
    vim -R -M -c "setl filetype=yaml" -
}
export TG_LOG_FORMAT="bare"

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
    archlinux)

# macOS (class work-mac): Homebrew's prefix, set here only, so every interactive
# shell gets it, login or not. mise's brew: manager installs there too, with or
# without Homebrew itself, so no `brew shellenv`. Set before oh-my-zsh so its
# compinit sees Homebrew's completions.
if [[ $OSTYPE == darwin* && -d /opt/homebrew/bin ]]; then
    typeset -U path fpath
    path=(/opt/homebrew/bin /opt/homebrew/sbin $path)
    fpath=(/opt/homebrew/share/zsh/site-functions $fpath)
fi

source $ZSH/oh-my-zsh.sh

# Package-owned shell integrations (Story 2.13). NVM changes versions only on
# explicit `nvm use`; directory changes never install or switch Node.
if [[ $OSTYPE == darwin* ]]; then
    # Homebrew packages the plugins pacman supplies on Linux; mise owns Node
    # (both declared in .config/mise/config.toml##os.Darwin).
    for zsh_plugin in zsh-autosuggestions zsh-syntax-highlighting; do
        if [[ -r /opt/homebrew/share/$zsh_plugin/$zsh_plugin.zsh ]]; then
            source /opt/homebrew/share/$zsh_plugin/$zsh_plugin.zsh
        fi
    done
    unset zsh_plugin
else
    if [[ -r /usr/share/nvm/init-nvm.sh ]]; then
        # init-nvm.sh makes $NVM_DIR and its two links with `mkdir -v`/`ln -v`,
        # which print in every new shell on a fresh HOME and fail with "File
        # exists" when two shells start at once. Make them quietly first, so
        # its own checks find them; a lost race is harmless and stays silent.
        nvm_dir=${NVM_DIR:-${XDG_CONFIG_HOME:+$XDG_CONFIG_HOME/nvm}}
        nvm_dir=${nvm_dir:-$HOME/.nvm}
        mkdir -p "$nvm_dir"
        for nvm_file in nvm.sh nvm-exec; do
            [[ -e $nvm_dir/$nvm_file ]] || ln -s /usr/share/nvm/$nvm_file "$nvm_dir/$nvm_file" 2>/dev/null
        done
        unset nvm_dir nvm_file
        source /usr/share/nvm/init-nvm.sh
    fi
    if [[ -r /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
        source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
    fi
    # antibody's static bundle sources plugins from antibody's cache, which
    # bootstrap's shell-caches step fills. Source it only when every file it
    # names exists, so a shell started before that (or under another HOME)
    # starts quietly. $(<file) reads without forking.
    if [[ -r ~/.zsh_plugins.sh ]]; then
        zsh_bundle_ok=1
        for zsh_plugin in ${${(M)${(f)"$(<~/.zsh_plugins.sh)"}:#source *}#source }; do
            [[ -r $zsh_plugin ]] || zsh_bundle_ok=0
        done
        (( zsh_bundle_ok )) && source ~/.zsh_plugins.sh
        unset zsh_bundle_ok zsh_plugin
    fi
fi

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
  export EDITOR='vim'
fi

# Compilation flags (Linux x86_64 only: on Apple Silicon this forces Intel builds)
if [[ $OSTYPE != darwin* ]]; then
    export ARCHFLAGS="-arch x86_64"
fi

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
alias sl="/usr/bin/sl -edw"
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
if [[ $OSTYPE != darwin* ]]; then
    # macOS ships its own pbcopy/pbpaste and has no systemd
    alias sctl="sudo systemctl"
    alias pbcopy="xclip -selection clipboard"
    alias pbpaste="xclip -selection clipboard -o"
fi
alias restart="shutdown -r now"
## reload xresources
alias xrl="xrdb ~/.Xresources"
alias nr="node run.js"
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
# Dormant: friend's Ansible playbook (patrick-motard/dot-ansible). Not the active
# update path; left as a pointer for the Story 2.3/2.5 architecture decision.
#alias update="ansible-playbook ~/code/dot-ansible/main.yml --ask-become-pass"
alias tools="cd ~/.local/bin/tools/ && ll"

alias npmis="npm install --save"
alias npmisd="npm install --save-dev"

alias cat="bat"
if [[ $OSTYPE == darwin* ]]; then
    # Homebrew has only exa's maintained fork
    alias ls="eza"
    alias ll="eza -la"
else
    alias ls="exa"
    alias ll="exa -la"
fi
alias gimme="sudo pacman -S"

alias c="cd ~/code && ll"
alias cggh="cd $GOPATH/src/github.com/$GITHUB_ACCOUNT && ll"
alias vssh="vim ~/.ssh/config"
alias lssh="ls ~/.ssh"
alias rmrf="rm -rfi"
alias update-emacs="$HOME/.local/bin/setup/spacemacs-checkout update"
alias news="new_script --path . --name"
alias newt="new_script --name"
alias ranger='ranger --choosedir=$HOME/.rangerdir; LASTDIR=`cat $HOME/.rangerdir`; cd "$LASTDIR"'
alias v='vim'
alias k='kubectl'

# Terraform
alias ti="terraform init"
alias ta="terraform apply"
alias td="terraform destroy"

# Terragrunt
alias tam="terragrunt apply --terragrunt-source ~/Documents/repos/terraform-modules//odp"
alias tdm="terragrunt destroy --terragrunt-source ~/Documents/repos/terraform-modules//odp"
alias trm="terragrunt refresh --terragrunt-source ~/Documents/repos/terraform-modules//odp"


export GO111MODULE=on

update_golang() {
    # update golang pacman package
    echo "\nUpdating golang...\n"
    sudo pacman -Sy --needed go
    echo "\nUpdating golang packages...\n"
    go get -u all
}

update_pacman_mirrorlist() {
    # Same policy the weekly reflector.timer uses (tracked at
    # .config/dotfiles/reflector.conf, symlinked into /etc/xdg by bootstrap 3b)
    # so a hand re-rank can never disagree with the scheduled one.
    sudo reflector --verbose @/etc/xdg/reflector/reflector.conf
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

alias homelab-up="docker stack deploy -c ~/code/homelab/docker-compose.yml homelab"
alias homelab-down="docker stack rm homelab"
alias homelab-status="docker service ls | grep homelab"
function generate_password() {
    password=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c 32; echo;)
    echo $password | pbcopy
    echo "New password copied to clipboard."
}
alias passgen=generate_password

## CUSTOM KEY BINDINGS ##
## zsh vi-mode settings
# remaps ESC to fd
#bindkey -M viins 'fd' vi-cmd-mode
#bindkey 'lk' autosuggest-accept

#export PATH=~/.local/lib/azure-cli/bin/:$PATH
export PATH=~/.local/bin/work:$PATH
export PATH=~/.local/bin:$PATH
export PATH=~/.bin:$PATH
export PATH=~/.local/bin/tools:$PATH
export PATH=~/.local/bin/setup:$PATH
export PATH=~/.nuget/plugins:$PATH
export PATH=/opt/idea-IC-171.4424.56/bin:$PATH
export PATH=/opt/teams-for-linux:$PATH
export PATH=/usr/share/intellijidea-ce/bin:$PATH
export PATH=~/.yarn/bin:$PATH
export PATH=~/.krew/bin:$PATH
export PATH=/usr/local/bin:$PATH

## NPM TOKEN SETUP
export NPM_TOKEN=$NPM_TOKEN

# ansible playbooks
export ANSIBLE_PLAYBOOKS_DIR=~/code/ansible-playbooks

#switch between different AWS accounts
alias check-mode="aws s3 ls"

alias dotfiles="cd ~/.config/dotfiles/"
alias copy-monitors='xrandr -q | grep " connected" | awk "{print $"${1:-1}"}" ORS=" " | pbcopy'


## CUSTOM KEY BINDINGS ##
## zsh vi-mode settings
# remaps ESC to fd

#use vim for manpages
#export MANPAGER="/bin/sh -c \"col -b | vim -c 'set ft=man ts=8 nomod nolist nonu noma' -\""
export MANPAGER='vim -R -M +MANPAGER -'

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
if [[ -f /usr/share/bash-completion/completions/az ]]; then
    autoload bashcompinit && bashcompinit
    source /usr/share/bash-completion/completions/az
fi

export ANSIBLE_PLAYBOOKS_DIR=~/code/ansible-playbooks

export PATH=$PATH:/home/han/.local/bin

autoload -U +X bashcompinit && bashcompinit
if [[ $OSTYPE != darwin* ]]; then
    export DOTNET_ROOT="/usr/share/dotnet"

    # Written by bootstrap's shell-caches step when broot is installed.
    if [[ -r $HOME/.config/broot/launcher/bash/br ]]; then
        source $HOME/.config/broot/launcher/bash/br
    fi

    # Written by bootstrap's shell-caches step when tenv is installed.
    if [[ -r $HOME/.tenv.completion.zsh ]]; then
        source $HOME/.tenv.completion.zsh
    fi

    # terraform/terragrunt completion runs the newest version tenv installed,
    # found on disk. `tenv tf detect` used to pick it, but with no version file
    # around it asks GitHub for the latest release, so every new shell hit the
    # network (and its rate limit). tenv reads TENV_GITHUB_TOKEN itself.
    for tenv_tool in terraform terragrunt; do
        tenv_bin=($HOME/.tenv/${(C)tenv_tool}/*/$tenv_tool(N*nOn[1]))
        if (( $#tenv_bin )); then
            complete -o nospace -C $tenv_bin[1] $tenv_tool
        fi
    done
    unset tenv_tool tenv_bin
fi

# macOS (class work-mac): mise activation.
if [[ $OSTYPE == darwin* ]]; then
    # This tracked file owns activation: config.toml##os.Darwin sets
    # mise_shell_activate zsh = false, so mise never writes its block here.
    if (( $+commands[mise] )); then
        eval "$(mise activate zsh)"
    fi
fi

# machine-local shell config (untracked; machine/site-specific aliases live there)
[[ -r ~/.zshrc.local ]] && source ~/.zshrc.local
