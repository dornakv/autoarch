#Coloring
WARNINGC='\033[0;31m'
IMPORTANTC='\033[0;36m'
NC='\033[0m'                # No Color

#Check the script is run as root (sudo)
check_root() {
if [ ! "$(id -u)" = 0 ]; then
        echo "I need to run as root!"
        exit -1
    fi
}
