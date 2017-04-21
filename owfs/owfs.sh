#!/usr/bin/env bash
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

### Script options
opt_help      "Fetch 1-wire sensor data"
opt_help_hint "See dist/owfs.conf for details."

### PVLng default options with flag for local time and save data
opt_define_pvlng x

. $(opt_build)

daemonize

read_config "$CONFIG"

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

### check owread binary
OWREAD=${OWREAD:-$(which owread)}
[ "$OWREAD" ] || error_exit "Missing owread binary!"

check_required SERVER "OWFS Server"

[ $(bool "$CACHED") -eq 0 ] && CACHED='/uncached' || CACHED=
[ -z "$CACHED" ] && log 1 "Use cached channel values"
[ -z "$UNIT" ] && UNIT=C

##############################################################################
### Go
##############################################################################
while true; do

    t=$(now)

    for i in $GUIDs; do

        sec 1 $i

        var1 GUID $i

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
            if [ "$MOUNTPOINT" ]; then
                lkv 2 Check ${MOUNTPOINT}${CACHED}/${SERIAL}/${CHANNEL}
                if [ ! -f "${MOUNTPOINT}${CACHED}/${SERIAL}/${CHANNEL}" ]; then
                    log 1 "FAILED, missing ${SERIAL}"
                    continue
                fi
            else
                rc=$(owpresent -$UNIT -s $SERVER ${CACHED}/${SERIAL}/${CHANNEL} 2>/dev/null)
                if [ $rc -ne 1 ]; then
                    log 1 "FAILED, missing ${SERIAL}"
                    continue
                fi
            fi
        fi

        ### read value
        if [ "$MOUNTPOINT" ]; then
            value=$(<${MOUNTPOINT}${CACHED}/${SERIAL}/${CHANNEL})
        else
            cmd="$OWREAD -$UNIT -s $SERVER ${CACHED}/${SERIAL}/${CHANNEL}"
            lkv 2 Request "$cmd"
            value="$($cmd 2>/dev/null)"
        fi
        lkv 1 Value "$value"

        ### Save data
        PVLngPUT $GUID $value

    done

    daemonize_check $t

done
