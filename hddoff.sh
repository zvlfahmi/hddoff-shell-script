#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [[ $EUID -ne 0 ]]; then
    echo -e "[ ${YELLOW}WARN${NC} ] This script must be run as root"
    exec sudo "$0" "$@"
fi

devices=$(lsblk -ln -o NAME | grep -E '^sd[a-z]$')

if [[ ! $devices ]]; then
    echo -e "[ ${YELLOW}WARN${NC} ] No removable devices found, exiting..."
    exit 0
fi

for device in $devices; do
    devicename=$(lsblk -ln -o MODEL /dev/$device)
    read -p "$(echo -e "${RED}=======>${NC} Do you want to eject $devicename ? [Y/n] ")" response
    ## ay, if you have a better way to do this, please let me know
    response=${response,,}
    if [[ $response =~ ^(yes|y| ) ]] || [[ -z $response ]]; then
        mountpoint=$(lsblk -ln -o MOUNTPOINT /dev/$device | grep -v '^$')
        
        if [[ $mountpoint ]]; then
            sync
            echo -e "[  ${GREEN}OK${NC}  ] Successfully flushed buffered memory to disk for /dev/$device"

            for partition in $(lsblk -ln -o NAME /dev/$device | grep -E '^sd[a-z][0-9]+$'); do
                umount /dev/$partition
                echo -e "[  ${GREEN}OK${NC}  ] Unmounted /dev/$partition"
            done

            if udisksctl power-off -b /dev/$device; then
                echo -e "[  ${GREEN}OK${NC}  ] Successfully powered off $devicename"
            else
                echo -e "[ FAIL ] Unable to power off $devicename"
            fi
        else
            echo -e "[ WARN ] $devicename is not mounted.. trying to power it off anyway"
            sync
            if udisksctl power-off -b /dev/$device; then
                echo -e "[  ${GREEN}OK${NC}  ] Successfully powered off $devicename"
            else
                echo -e "[ ${RED}FAIL${NC} ] Unable to power off $devicename"
            fi
        fi
    else
        echo "[ INFO ] Skipping /dev/$device"
    fi
done

