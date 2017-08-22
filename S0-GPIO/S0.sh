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
    local cmd="$S0 -p $CHANNEL -r $RESOLUTION -l $LOG"

    [ "$TEST" ] && lkv 1 TEST "$cmd" && return

    lkv 1 "Start listener" "$cmd"
    ### Start read of device in watt mode!
    eval "$cmd &"
}

##############################################################################
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

    if [ $(bool $IMPULSES) -eq 1 ]; then
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

: ${PYTHON:=$(which python2)}
S0="$PYTHON $pwd/bin/S0.py"

### Script options
opt_help      "Read S0 impulses via GPIO pin"
opt_help_hint "See dist/S0.conf for details."

opt_define short=a long=abort desc="Abort listening, kill all running S0 processes" variable=ABORT value=y

### PVLng default options with flag for local time and save data
opt_define_pvlng x

. $(opt_build)

read_config "$CONFIG"

check_lock $(basename $CONFIG)

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

check_required GUID 'Channel GUID'

check_default RESOLUTION 1000
[ $RESOLUTION -gt 0 ] || exit_required "Sensor resolution (positive integer)" RESOLUTION

check_default IMPULSES 0

if [ ! "$CHANNEL" ]; then
    ### Read from API
    PVLngChannelAttr $GUID CHANNEL
fi
[ "$CHANNEL" ] || exit_required "GPIO pin (maintain as 'channel' for channel $GUID)" CHANNEL

##############################################################################
### Go
##############################################################################
### Log file for measuring data
LOG=$(run_file S0-GPIO "$CONFIG")

lkv 1 'GPIO pin' $CHANNEL

### Identify S0 listener process by device attached to
### Put whole "ps ax" output into an array, $pid then shows the same as ${pid[0]}
pid=($(ps ax | grep -e "[ /]S0.py" | grep "$CHANNEL"))

if [ ! "$pid" ]; then
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
    else
        S0SaveData
    fi
fi

exit 0
