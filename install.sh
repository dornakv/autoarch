#!/usr/bin/env bash

# Settings:
hostname="scs_pc"
username="scoks"
swapsize="auto"             # "auto" sets it to the MemTotal in /proc/meminfo (amount of detected RAM)
device="/dev/sdb"           # Drive for install
efi_device="${device}1"     # this is different for nvme and non-nvme drives TODO: should be automated based on device string
root_device="${device}2"
agreed=false                # If set to true, will skip confirmation at the begining

base_system=( base base-devel linux linux-firmware neovim networkmanager) # Check archwiki installation guide what is currently needed
# base-devel contains sudo, pacman, gcc and other useful tools


# Script variables, do not change please
WARNINGC='\033[0;31m'
IMPORTANTC='\033[0;36m'
NC='\033[0m'                # No Color
DEVICESTR="${IMPORANTC}"

# Check if running from archiso
check_archiso() {
    if [ ! "$(uname -n)" = "archiso" ]; then
        echo "I can only be run from the Archlinux live medium!"
        exit -1
    fi
}

# Check if user is root
check_root() {
if [ ! "$(id -u)" = 0 ]; then
        echo "I need to run as root!"
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

# Show user the selected settings, if user did not agree yet, ask for confirmation
check_settings() {
    echo -e "System will be installed to ${IMPORTANTC}${device}${NC} ${WARNINGC}(WILL BE FORMATED!)${NC}"
    echo -e "Swap will set to ${IMPORTANTC}${swapsize} mB${NC}"
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
    mkfs.ext4 -L -n "ROOT" ${root_device}
}

# Mounting partitions
mount_partitions() {
    echo "Mounting root partition to /mnt"
    mkdir -p /mnt
    mount -t ext4 ${root_device} /mnt

    echo "Mounting efi partition to /mnt/boot"
    mkdir -p /mnt/boot
    mount -t vfat ${efi_device} /mnt/boot
}

# Installing base system to disk
base_install() {
    echo "Installing base system to disk"
    pacstrap /mnt ${pacstrap_packages} --noconfirm --needed
}

# Generate fstab file
gen_fstab() {
    genfstab -U /mnt >> /mnt/etc/fstab
}

#check_archiso
#check_root
check_UEFI
set_SWAP
#timedatectl set-ntp true # Set up system clock
check_settings
prep_device
mount_partitions

base_install
gen_fstab
