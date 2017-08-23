#!/bin/bash
##############################################################################
### @author      Knut Kohl <github@knutkohl.de>
### @copyright   2012 Knut Kohl
### @license     MIT License (MIT) http://opensource.org/licenses/MIT
##############################################################################

##############################################################################
### Constants
##############################################################################
pwd=$(dirname $0)

##############################################################################
### Init
##############################################################################
. $pwd/../PVLng.sh

### Script options
opt_help      "Fetch memory usage"
opt_help_hint "See dist/memory.conf for details."

### PVLng default options with flag for local time and save data
opt_define_pvlng x

. $(opt_build)

read_config "$CONFIG"

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

##############################################################################
### Go
##############################################################################
### Memory usage snapshot
cp /proc/meminfo $TMPFILE

log 2 @$TMPFILE /proc/meminfo

### Transform output to variable settings, so
### MemTotal:        7162764 kB
### becomes
### MemTotal=7162764
while read line; do
    eval $(echo $line | sed 's/[()]//g' | awk -F':| +' '{print $1"="$3}')
done <$TMPFILE

for i in $(getGUIDs); do

    sec 1 $i

    ### If not USE is set, set to $i
    var1 USE $i $i
    var1 GUID $USE

    var1 KEY $i

    ### https://stackoverflow.com/a/17383066
    ### \< matches the transition from non-word to word.
    KEY=$(echo $KEY | sed -e 's/\</$/g')

    lkv 2 Formula "$KEY"

    ### Try to replace variables with numerics
    eval KEY=\"$KEY\"
    lkv 2 Formula "$KEY"

    value=$(calc "$KEY" 0)

    lkv 1 Value $value

    ### Save data
    PVLngPUT $GUID $value

done
