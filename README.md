# WIP
This script is not yet ready and not even tested. Still work in progress.

# Autoarch
My script for automated installation of Arch Linux. Use only for inspiration as it may break your computer or might not be set up in a way you want your instllation to be set up.  
Check that you have selected the drive you are ok with being wiped. This is set as "device" variable at the begining of the script "install.sh"  
For nvme set the "efi\_device" and "root\_device" as "device" as "${device}p1" and "${device}p2" respectively.  

# Sources of inspiration:
[Reddit thread with links to installation scripts](https://www.reddit.com/r/archlinux/comments/ob9ufn/how_can_i_make_an_arch_install_script/)
[Lists of packages to pacstrap](https://github.com/deepbsd/Farchi/blob/master/farchi.sh)
[Simple to follow preinstall script](https://github.com/johnynfulleffect/ArchMatic/blob/master/preinstall.sh)
[Separated to methods, which can be called depending on in which context the script is run](https://github.com/mietinen/archer)
