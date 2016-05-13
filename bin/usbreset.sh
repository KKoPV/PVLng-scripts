#!/bin/sh

[ -z "$1" ] && printf "\nUsage: %s <identifier>\n\n" $0 && exit 1

device=$(lsusb | grep $1 | awk -F' |:' '{printf "/dev/bus/usb/%s/%s", $2, $4}')

$(dirname $0)/usbreset $device
