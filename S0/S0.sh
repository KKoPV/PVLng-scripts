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

### check S0 binary
S0=$(dirname $0)/bin/S0
[ -x "$S0" ] || error_exit 'Missing "'$S0'" binary, please compile first!'

### Script options
opt_help      "Read S0 impulses"
opt_help_args "<config file>"
opt_help_hint "See dist/S0.conf for details."

opt_define short=a long=abort desc="Abort listening, kill all running S0 processes" variable=ABORT value=y

### PVLng default options with flag for local time and save data
opt_define_pvlng x

source $(opt_build)

### Don't check lock file in test mode
[ "$TEST" ] || check_lock $(basename $1)

CONFIG="$1"

read_config "$CONFIG"

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

GUID_N=$(int "$GUID_N")
[ $GUID_N -gt 0 ] || error_exit "No sections defined"

##############################################################################
### Start listener
##############################################################################
function S0StartListener() {
    local cmd="$S0 -d $CHANNEL -r $RESOLUTION -l $LOG"

    if [ "$TEST" ]; then
        lkv 1 TEST "$cmd"
        return
    fi

    lkv 1 "Start listener" "$cmd"
    ### Start read of device in watt mode!
    $($cmd)
}

##############################################################################
### Save data
##############################################################################
function S0SaveData() {

    ### log exists and is not empty?
    [ -s "$LOG" ] || return 0

    ### In test mode leave log file as is
    [ "$TEST" ] && cp $LOG $TMPFILE || mv $LOG $TMPFILE

    ### Number of readings
    local impulses=$(wc -l $TMPFILE | cut -d' ' -f1)
    lkv 1 impulses $impulses

    if [ $IMPULSES -eq 0 ]; then
        ### Calculate average power
        local power=0
        while read p; do
            lkv 1 power $p
            power=$(calc "$power + $p")
        done <$TMPFILE

        power=$(calc "$power / $impulses")

        lkv 1 average $power

        ### Save average power
        [ "$TEST" ] || PVLngPUT $GUID $power
    else
        ### Save impulses
        [ "$TEST" ] || PVLngPUT $GUID $impulses
    fi

}

##############################################################################
### Go
##############################################################################
i=0

while [ $i -lt $GUID_N ]; do

    i=$((i+1))

    sec 1 $i

    var1 GUID $i
    [ "$GUID" ] || error_exit "Sensor GUID is required (GUID_$i)"
    lkv 1 GUID $GUID

    var1 CHANNEL $i
    if [ -z "$CHANNEL" ]; then
        ### Read from API
        PVLngChannelAttr $GUID CHANNEL
    fi

    [ "$CHANNEL" ] || error_exit "Device is required, maintain as 'channel' for channel $GUID"
    lkv 1 Device $CHANNEL

    if [ ! -r "$CHANNEL" ]; then
        echo
        echo Device $CHANNEL is not readable for script running user!
        echo
        ls -l "$CHANNEL"
        echo
        echo Please make sure the user is at least added to the group which ownes the device.
        exit 2
    fi

    var1 RESOLUTION $i
    [ "${RESOLUTION:-0}" -gt 0 ] || error_exit "Sensor resolution must be a positive integer (RESOLUTION_$i)!"

    var1 IMPULSES $i
    IMPULSES=$(bool ${IMPULSES:-0})

    ### log file for measuring data
    LOG=$(run_file S0 $CONFIG $i.log)
    lkv 1 Log $LOG

    ### Identify S0 process by device attached to!
    pid=$(ps ax | grep -e "[ /]S0" | grep "$CHANNEL" | sed -e 's/^ *//' | cut -d' ' -f1)

    if [ -z "$pid" ]; then
        ##########################################################################
        ### Mostly 1st run, start S0 listener
        ##########################################################################
        S0StartListener

    else
        ############################################################################
        ### Fine, S0 is running
        ############################################################################
        if [ "$ABORT" ]; then
            log 0 "Stop listening"
            log 0 "Kill process $pid ..."
            kill $pid
            log 0 "Remove log $LOG ..."
            rm $LOG
            log 0 'Done'
            exit
        fi

        S0SaveData
    fi

done
