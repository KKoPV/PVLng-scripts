#!/bin/bash
##############################################################################
### @author      Knut Kohl <github@knutkohl.de>
### @copyright   2012-2015 Knut Kohl
### @license     MIT License (MIT) http://opensource.org/licenses/MIT
### @version     1.0.0
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
temp_file MEMFILE

cat /proc/meminfo >$MEMFILE

log 2 @$MEMFILE /proc/meminfo

for i in $GUIDs; do

    sec 1 $i

    ### If not USE is set, set to $i
    var1 USE $i $i
    var1 GUID $USE

    var1 KEY $i

    set -- $(grep "$KEY" $MEMFILE | sed -e 's/[: ]\+/\t/g')
    [ "$1" ] || continue

    lkv 1 Value $2

    ### Save data
    PVLngPUT $GUID $2

done
