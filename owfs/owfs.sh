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

### Defaults
SERVER="localhost:4304"
CACHED=false

##############################################################################
### Init
##############################################################################
. $pwd/../PVLng.sh

### check owread binary
OWREAD=${OWREAD:-$(which owread)}
[ "$OWREAD" ] || error_exit "Missing owread binary!"

### Script options
opt_help      "Fetch 1-wire sensor data"
opt_help_hint "See dist/owfs.conf for details."

### PVLng default options with flag for local time and save data
opt_define_pvlng x

source $(opt_build)

read_config "$CONFIG"

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

[ "$SERVER" ] || exit_required "OWFS Server" SERVER

GUID_N=$(int "$GUID_N")
[ $GUID_N -gt 0 ] || exit_required Sections GUID_N

[ $(bool "$CACHED") -eq 0 ] && CACHED='/uncached' || CACHED=
[ -z "$CACHED" ] && log 1 "Use cached channel values"
[ -z "$UNIT" ] && UNIT=C

##############################################################################
### Go
##############################################################################
i=0

while [ $i -lt $GUID_N ]; do

    i=$(($i+1))

    sec 1 $i

    ### GUID given?
    var1 GUID $i
    [ -z "$GUID" ] && log 1 Skip && continue

    var1 SERIAL $i
    if [ -z "$SERIAL" ]; then
        ### Read from API
        PVLngChannelAttr $GUID SERIAL
#       SERIAL=$(PVLngNC "$GUID,serial")
    fi

    var1 CHANNEL $i
    if [ -z "$CHANNEL" ]; then
        ### Read from API
        PVLngChannelAttr $GUID CHANNEL
#       CHANNEL=$(PVLngNC "$GUID,channel")
    fi

    if [ "$TEST" ]; then
        lkv 1 Channel "/${SERIAL}/${CHANNEL}"
        rc=$(owpresent -$UNIT -s $SERVER ${CACHED}/${SERIAL}/${CHANNEL} 2>/dev/null)
        if [ $rc -ne 1 ]; then
            log 1 "FAILED, missing ${SERIAL}"
            continue
        fi
    fi

    ### read value
    cmd="$OWREAD -$UNIT -s $SERVER ${CACHED}/${SERIAL}/${CHANNEL}"
    lkv 2 Request "$cmd"
    value="$($cmd 2>/dev/null)"
    lkv 1 Value "$value"

    ### Save data
    PVLngPUT $GUID $value

done
