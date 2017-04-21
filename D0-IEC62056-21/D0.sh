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
opt_help      "Read D0 data from energy meters"
opt_help_hint "See D0.conf.dist for details."

### PVLng default options with flag for save data
opt_define_pvlng x

. $(opt_build)

read_config "$CONFIG"

check_lock $(basename $CONFIG)

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

check_required DEVICE Device

##############################################################################
### Go
##############################################################################
temp_file DATAFILE

fetch="$pwd/bin/IEC-62056-21.py -d $DEVICE >$DATAFILE"

log 2 "Run $fetch"

### Read data
eval $fetch

[ -s $DATAFILE ] || exit

log 2 @$DATAFILE

for i in $GUIDs; do

    sec 1 $i

    ### If not USE is set, set to $i
    var1 USE $i $i
    var1 GUID $USE

    var1 OBIS $i
    if [ -z "$OBIS" ]; then
        ### Read from API
        PVLngChannelAttr $GUID CHANNEL
        OBIS=$CHANNEL
    fi

    [ "$OBIS" ] || error_exit "OBIS Id is required, maintain as 'channel' for channel $GUID"
    lkv 1 "Used OBIS" "$OBIS"

    ### Mask * for grep
    expr=$(echo $OBIS | sed 's~\*~[*]~g')
    set -- $(grep $expr $DATAFILE)

    ### Eliminate leading zeros
    value=$(calc "$2")

    lkv 1 Value "$value"

    [ "$value" ] || continue

    PVLngPUT $GUID $value

done
