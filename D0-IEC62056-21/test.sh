#!/bin/bash
##############################################################################
###
###
###
##############################################################################
if [ $# -ne 1 ]; then
    echo
    echo "Usage: $0 <device>"
    echo
    echo "Device name is required!"
    echo
    exit 1
fi

pwd=$(dirname $0)

TMPFILE=$(mktemp)
trap "rm $TMPFILE" 0

echo
echo Fetch data, this may take some seconds ...
echo

cmd=$pwd/bin/IEC-62056-21.py

$cmd -d $1 >$TMPFILE

error=$(grep ERROR $TMPFILE)

if [ "$error" ]; then
    echo "$error"
    echo
    echo "If there is an error opening the device, make sure your user is member of group 'dialout'."
    echo
    exit 1
fi

echo "1. Raw data delivered by meter"
echo

$cmd -d $1 -rv

echo "2. Analysed OBIS keys"
echo

while read line; do
    ### Split reading into address and value
    set $line

    ### Extract OBIS code and grep for description
    obis=$(echo $1 | cut -d':' -f2 | cut -d'*' -f1)
    name=$(grep $obis $pwd/doc/OBIScodes.txt | cut -f2-)

    echo "$1 ($name) = $2"
done <$TMPFILE

echo
echo 'Put the 1st part (?-?:?.?.?*255) into your configuration file.'
