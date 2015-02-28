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
### Functions
##############################################################################
S0StartListener () {
    local cmd="$S0 -d $CHANNEL -r $RESOLUTION -l $LOG"

    if [ "$TEST" ]; then
        lkv 1 TEST "$cmd"
        return
    fi

    lkv 1 "Start listener" "$cmd"
    ### Start read of device in watt mode!
    $($cmd)
}

S0SaveData () {
    ### log exists and is not empty?
    [ -s "$LOG" ] || return

    ### In test mode leave log file as is, work on a copy
    [ "$TEST" ] && cp $LOG $TMPFILE || mv $LOG $TMPFILE

    ### Number of readings and average power
    set -- $(awk '{s+=$1; n++} END {if (n>0) printf "%d\t%.4f",n,s/n;}' $TMPFILE)

    [ "$1" ] || return

    lkv 1 Impulses $1
    lkv 1 "Average power" "$2 W"

    [ "$TEST" ] && return

    if [ $IMPULSES -eq 1 ]; then
        ### Save impulses
        PVLngPUT $GUID $1
    else
        ### Save average power
        PVLngPUT $GUID $2
    fi
}

##############################################################################
### Init
##############################################################################
. $pwd/../PVLng.sh

### check S0 binary
S0=$pwd/bin/S0
[ -x "$S0" ] || error_exit 'Missing "'$S0'" binary, please make and install first!'

### Script options
opt_help      "Read S0 impulses"
opt_help_args "<config file>"
opt_help_hint "See dist/S0.conf for details."

opt_define short=a long=abort desc="Abort listening, kill all running S0 processes" variable=ABORT value=y

### PVLng default options with flag for local time and save data
opt_define_pvlng x

. $(opt_build)

CONFIG=$1

read_config "$CONFIG"

### Don't check lock file in test mode
[ "$TEST" ] || check_lock $(basename $CONFIG)

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

GUID_N=$(int "$GUID_N")
[ $GUID_N -gt 0 ] || exit_required Sections GUID_N

##############################################################################
### Go
##############################################################################
i=0

while [ $i -lt $GUID_N ]; do

    i=$((i+1))

    sec 1 $i

    var1 GUID $i
    [ -z "$GUID" ] && log 1 Skip && continue

    var1 CHANNEL $i
    if [ -z "$CHANNEL" ]; then
        ### Read from API
        PVLngChannelAttr $GUID CHANNEL
    fi

    [ "$CHANNEL" ] || exit_required "Device (maintain as 'channel' for channel $GUID)" CHANNEL_$i
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

    var1int RESOLUTION $i 0
    [ $RESOLUTION -gt 0 ] || exit_required "Sensor resolution (positive integer)" RESOLUTION_$i

    var1bool IMPULSES $i 0

    ### Log file for measuring data
    LOG=$(run_file S0 "$CONFIG" $i.log)

    ### Identify S0 listener process by device attached to
    ### Put whole "ps ax" output into an array, $pid then shows the same as ${pid[0]}
    pid=($(ps ax | grep -e "[ /]S0" | grep "$CHANNEL"))

    if [ -z "$pid" ]; then
        ### Mostly 1st run, start S0 listener
        S0StartListener

    else
        ### Fine, S0 listener is running
        lkv 1 "S0 listener pid" $pid

        if [ "$ABORT" ]; then
            log 0 "Stop listener daemon"
            log 0 "Kill process $pid ..."
            kill $pid
            log 0 "Remove log $LOG ..."
            rm "$LOG" 2>/dev/null
            log 0 'Done'
            exit
        fi

        S0SaveData
    fi

done
