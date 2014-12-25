#!/bin/bash
##############################################################################
### @author      Knut Kohl <github@knutkohl.de>
### @copyright   2012-2014 Knut Kohl
### @license     MIT License (MIT) http://opensource.org/licenses/MIT
### @version     1.0.0
##############################################################################

##############################################################################
### Init
##############################################################################
pwd=$(dirname $0)

source $pwd/../PVLng.sh

### Script options
opt_help      "Read D0 data from energy meters"
opt_help_args "<config file>"
opt_help_hint "See D0.conf.dist for details."

### PVLng default options with flag for save data
opt_define_pvlng x

source $(opt_build)

CONFIG="$1"

read_config "$CONFIG"

### Don't check lock file in test mode
[ "$TEST" ] || check_lock $(basename $CONFIG)

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

[ "$DEVICE" ] || error_exit "No Device defined (DEVICE)"

GUID_N=$(int "$GUID_N")
[ $GUID_N -gt 0 ] || error_exit "No sections defined (GUID_N)"

##############################################################################
### Go
##############################################################################
DATAFILE=$(temp_file)

### Read data
$pwd/bin/IEC-62056-21.py -d $DEVICE >$DATAFILE

[ -s $DATAFILE ] || exit

log 1 "Fetched data:"
log 1 @$DATAFILE

i=0

while [ $i -lt $GUID_N ]; do

    i=$((i+1))

    log 1 "--- Section $i ---"

    var1 GUID $i
    if [ -z "$GUID" ]; then
        echo "Skip"
        continue
    fi
    log 1 "GUID      : $GUID"

    eval CHANNEL=\$OBIS_$i

    if [ -z "$CHANNEL" ]; then
        ### Read from API
        PVLngChannelAttr $GUID CHANNEL
    fi

    [ "$CHANNEL" ] || error_exit "OBIS Id is required, maintain as 'channel' for channel $GUID"
    log 1 "OBIS Id   : $CHANNEL"

    ### Mask * for grep
    expr=$(echo $CHANNEL | sed -e 's/\*/[*]/g')
    value=$(grep $expr $DATAFILE | cut -f2)
    log 1 "Value     : $value"

    [ "$value" ] || continue
    [ "$TEST" ] && continue

    PVLngPUT $GUID $value

done
