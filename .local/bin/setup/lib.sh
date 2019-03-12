#!/usr/bin/env zsh

# lib.sh is shared functionality between setup and install scripts.

# code may be ported to here from  install as update starts to catch
# up with install in functionality. Long term I would like to
# combine install and update as commands in the dot golang CLI.

# ~/.config/dotfiles/arch-packages/pacman is a list of packages
# for the dotfiles repo (arch packages, not AUR). This function
# installs all of the packages from that list.
function install_pacman_packages() {
    IFS=$'\n' common_pacman_packages=($(cat ~/.config/dotfiles/arch-packages/pacman))
    for package_name in $common_pacman_packages; do
        output=$(yay -S $package_name --noconfirm --needed --quiet)
        if [ "$output" != " there is nothing to do" ]; then
            echo "$output"
        fi
    done
}
