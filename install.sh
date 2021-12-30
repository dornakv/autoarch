#!/usr/bin/env bash

check_root() {
if [ ! "$(id -u)" = 0 ]; then
        echo "I need to run as root!"
        exit -1
    fi
}

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

