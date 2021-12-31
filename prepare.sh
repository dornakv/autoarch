#!/usr/bin/env bash
source ./helpers/lib.sh


# Settings:
hostname="scs_pc"
username="scoks"
password=""                 # keep empty, will be asked at the start of the script
dotfiles_url="https://github.com/dornakv/dotfiles.git"
dotfiles_dir="/home/${username}/dotfiles"
swapsize="auto"             # "auto" sets it to the MemTotal in /proc/meminfo (amount of detected RAM)
device="/dev/sdb"           # Drive for install
efi_device="${device}1"     # this is different for nvme and non-nvme drives TODO: should be automated based on device string
root_device="${device}2"
agreed=false                # If set to true, will skip confirmation at the begining
aditional_mount_device="/dev/sda1"
aditional_mount_point="/mnt/kingpin"
time_zone="Europe/Prague"   # timedatectl list-timezones

base_system=( base linux linux-firmware) # Check archwiki installation guide what is currently needed
# base-devel contains sudo, pacman, gcc and other useful tools
# network is installed and set up in set_network function

dotfiles="https://github.com/dornakv/dotfiles.git"

# Script variables, do not change please
DEVICESTR="${IMPORANTC}"

# Check if running from archiso
check_archiso() {
    if [ ! "$(uname -n)" = "archiso" ]; then
        echo "I can only be run from the Archlinux live medium!"
        exit -1
    fi
}

# Check if running in UEFI boot mode
check_UEFI() {
    if [ ! -d "/sys/firmware/efi/efivars" ]; then
        echo "I can only install in UEFI!"
        exit -1
    fi
}

# Set swapsize to the amount of ram if set to auto
set_SWAP() {
    if [ "${swapsize}" = "auto" ]; then
        swapsize=$((($(grep MemTotal /proc/meminfo | awk '{print $2}')+500)/1000))
    fi
}

set_password() {
    if [ -z "${password}" ]; then
        read -s -p "Input a password for the user and the root: " password
        echo -e "\n"
    fi
}

# Show user the selected settings, if user did not agree yet, ask for confirmation
check_settings() {
    lsblk
    echo -e "System will be installed to ${IMPORTANTC}${device}${NC} ${WARNINGC}(WILL BE FORMATED!)${NC}"
    echo -e "Swap will be set to ${IMPORTANTC}${swapsize} mB${NC}"
    if $agreed ; then
        return
    fi
    read -p "If you agree with the proposed settings, type \"agree\" to continue: " agree
    if [ ! "${agree}" = "agree" ]; then
        echo "Exiting, bye"
        exit
    fi
    agreed=true
    echo "You agreed!"
}

# Disk preparation inspired by: https://github.com/johnynfulleffect/ArchMatic/blob/master/preinstall.sh
prep_device() {
    echo -e "Formating disk ${IMPORTANTC}${device}${NC}"
    # disk preparation
    wipefs -af ${device}

    sgdisk -Z ${device}             # Zap disk
    sgdisk -a 2048 -o ${device}     # new gpt disk 2048 alignment

    # create partitions
    sgdisk -n 1:0:+512M ${device}   # UEFI (512M)
    sgdisk -n 2:0:0 ${device}       # ROOT (remaining)

    # set partition types (https://askubuntu.com/questions/703443/gdisk-hex-codes)
    sgdisk -t 1:ef00 ${device}      # ef00 = EFI System
    sgdisk -t 2:8300 ${device}      # 8300 = Linux filesystem

    # label partitions
    sgdisk -c 1:"UEFISYS" ${device}
    sgdisk -c 2:"ROOT" ${device}

    echo -e "Creating filesystems on ${IMPORTANTC}${device}${NC}"
    mkfs.vfat -F32 -n "UEFISYS" ${efi_device}
    mkfs.ext4 -L "ROOT" ${root_device}
}

# Mounting partitions
mount_partitions() {
    echo "Mounting root partition to /mnt"
    mkdir -p /mnt
    mount -t ext4 ${root_device} /mnt

    echo "Mounting efi partition to /mnt/boot"
    mkdir -p /mnt/boot/efi
    mount -t vfat ${efi_device} /mnt/boot/efi

    echo "Mounting extra partition" # If we mount it now, it gets auto generated into fstab with genfstab???
    mkdir -p /mnt/${aditional_mount_point}
    mount ${aditional_mount_device} /mnt/${aditional_mount_point}
}

update(){
    echo "Updating"
    pacman -Syy --noconfirm
}

# Installing base system to disk
essential_install() {
    echo "Installing base system to disk"
    echo ${pacstrap_packages}
    pacstrap /mnt ${pacstrap_packages} --noconfirm --needed
}

# Generate fstab file
gen_fstab() {
    echo "Generating fstab to /mnt/etc/fstab"
    genfstab -U /mnt >> /mnt/etc/fstab
}

chroot() {
    cp "$0" /mnt/prepare.sh        # Copy this script to our new installation
    chmod 755 /mnt/prepare.sh      # The script needs to be executable
    arch-chroot /mnt /prepare.sh --chroot
    rm -f /mnt/prepare.sh
}

set_network() {
     pacman -S git networkmanager --noconfirm --needed
     systemctl enable NetworkManager.service
}

# Set language, formats, timezone, keyboard..
set_locale() {
    hwclock --systohc                   # Set the Hardware Clock from the System Clock and generate /etc/adjtime
    sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
    locale-gen
    timedatectl --no-ask-password set-timezone ${time_zone}
    timedatectl --no-ask-password set-ntp 1
    localectl --no-ask-password set-locale LANG="en_US.UTF-8" LC_TIME="en_US.UTF-8"
    localectl --no-ask-password set-keymap us
}

set_hostname() {
    printf "%s\n" "${hostname}" > /etc/hostname
    printf "%-15s %s\n" "127.0.0.1" "localhost" > /etc/hosts
    printf "%-15s %-15s %-15s %-15s\n" "::1" "localhost" "ip6-localhost" "ip6-loopback" >> /etc/hosts
    printf "%-15s %-15s %-15s %-15s\n" "127.0.1.1" "{$hostname}" "${hostname}" >> /etc/hosts
}

set_grub() {
    pacman -S grub efibootmgr --noconfirm --needed
    grub-install --targer=x86_64-efi --bootloader-id=GRUB --efi-directory=/boot/efi
    grub-mkconfig -o /boot/grub/grub.cfg
}

enable_multilib() {
    sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
    pacman -Sy --noconfirm
}

create_user() {
    mkdir -p /etc/sudoers.d/
    chmod 750 /etc/sudoers.d/
    echo "root ALL=(ALL) ALL" > /etc/sudoers.d/root
    echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel
    useradd --create-home --groups wheel --shell /bin/bash ${username}
    echo ${password} | passwd --stdin ${username}
}

get_dotfiles(){
    git clone ${dotfiles_url} ${dotfiles_dir}
}

if [ "$1" != "--chroot" ]; then
    check_archiso
    check_root
    check_UEFI
    set_SWAP
    set_password
    timedatectl set-ntp true # Set up system clock
    check_settings
    prep_device
    mount_partitions
    update
    essential_install
    gen_fstab
    chroot
else
    set_network
    set_locale
    set_hostname
    set_grub
    enable_multilib
    create_user
    get_dotfiles
    source install.sh
fi
