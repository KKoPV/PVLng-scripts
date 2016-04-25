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

TIMEOUT=30

##############################################################################
### Init
##############################################################################
. $pwd/../PVLng.sh

### Script options
opt_help      "Read data from Kaco inverters connected by RS485"
opt_help_hint "See dist/config.conf for details."

### PVLng default options with flag for save data
opt_define_pvlng x

. $(opt_build)

read_config "$CONFIG"

### Run only during daylight +- 60 min
check_daylight 60

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

### Check required settings
[ "$DEVICE" ]|| exit_required Device DEVICE

GUID_N=$(int "$GUID_N")
[ $GUID_N -gt 0 ]|| exit_required Sections GUID_N

##############################################################################
### Go
##############################################################################
# sudo chmod 666 /dev/ttyUSB0
stty -F $DEVICE 9600 cs8

i=0

while [ $i -lt $GUID_N ]; do

    i=$((i+1))

    sec 1 $i

    ### shortcut for GUID=GUID_$i
    var1 GUID $i
    [ -z "$GUID" ] && log 1 Skip && continue

    var1 INVERTER $i
    [ "$INVERTER" ] || exit_required "Inverter number" INVERTER_$i

    QUERY="#$(printf '%02d' $INVERTER)0\r"

    ### Log output key = value
    lkv 2 QUERY $QUERY

    ### Send query sequence
    echo -e $QUERY >$DEVICE

    ### Initialize data string
    data=

    ### Read char by char with defined timeout
    while IFS= read -r -t $TIMEOUT -n 1 c; do

        ### Skip 1st \r (response is then still empty)
        [ -z "$c" -a "$data" ] && break

        ### Concatenate response string
        data="$data$c"

    done <$DEVICE

    [ -z "$data" ] && log 1 'Got no data ...' && continue

    ### Clean up response, translate non printable check digit
    data=$(echo "$data" | tr -C '\12\40-\176' ? | sed 's/[^a-zA-Z0-9.*-]/ /g')

    ### Condense multiple spaces to one
    data=$(echo "$data" | sed 's/  */ /g')

    ### Save data, extend response with actual timestamp
    PVLngPUT $GUID "$(date +'%F %H:%M:%S') $data"

done
