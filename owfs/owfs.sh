#!/bin/sh
##############################################################################
### @author      Knut Kohl <github@knutkohl.de>
### @copyright   2012-2014 Knut Kohl
### @license     MIT License (MIT) http://opensource.org/licenses/MIT
### @version     1.0.0
##############################################################################

##############################################################################
### Init
##############################################################################
source $(dirname $0)/../PVLng.sh

### check owread binary
owread=${owread:=$(which owread)}
[ "$owread" ] || error_exit "Missing owread binary!"

### Script options
opt_help      "Fetch 1-wire sensor data"
opt_help_args "<config file>"
opt_help_hint "See owfs.conf.dist for details."

### PVLng default options with flag for save data
opt_define_pvlng x

source $(opt_build)

SERVER="localhost:4304"
CACHED=false

read_config "$1"

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

GUID_N=$(int "$GUID_N")
[ $GUID_N -gt 0 ] || error_exit "No sections defined (GUID_N)"

##############################################################################
### Go
##############################################################################
[ $(bool "$CACHED") -eq 0 ] && CACHED='/uncached' || CACHED=
[ -z "$CACHED" ] && log 1 "Use cached channel values"
[ -z "$UNIT" ] && UNIT=C

i=0

while test $i -lt $GUID_N; do

    i=$(($i+1))

    log 1 "--- GUID $i ---"

    var1 GUID $i
    test "$GUID" || error_exit "Sensor GUID is required (GUID_$i)"

    var1 SERIAL $i
    if test -z "$SERIAL"; then
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

    ### read value
    cmd="$owread -$UNIT -s $SERVER ${CACHED}/${SERIAL}/${CHANNEL}"
    log 2 $cmd
    value=$($cmd)
    log 1 "Value        = $value"

    ### Save data
    [ "$TEST" ] || PVLngPUT $GUID $value

done
