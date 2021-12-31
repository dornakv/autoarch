#!/usr/bin/env bash
source ./helpers/lib.sh

install_yay() {
    cd /tmp
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg --noconfirm -si
}

check_root
pacman -Syyu
pacman --noconfirm --needed -S - < packages/common
pacman --noconfirm --needed -S - < packages/desktop
install_yay
yay --noconfirm -S < packages/desktop.aur

