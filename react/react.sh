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
script_name () {
    ### $1 - Action id
    local script=$(key_name '' "$CONFIG" $1)
    ### Remove leading dot from script name
    echo $pwd/scripts/${script:1}.sh
}

doAction () {
    ### $1 - Action id
    local script=$(script_name $1)

    [ -f $script ] || error_exit "Missing action script: $script"

    lkv 1 "Action script" "$script"

    [ "$TEST" ] && return

    bash $script $timestamp $value
}

##############################################################################
### Init
##############################################################################
. $pwd/../PVLng.sh

### Script options
opt_help      "React with commands or scripts on channel readings"
opt_help_args "<config file>"
opt_help_hint "See dist/react.conf for details."

opt_define short=f long=force desc="Force reaction also if condition not changed" variable=FORCE value=y

### PVLng default options
opt_define_pvlng

. $(opt_build)

CONFIG=$1

fallback=$(script_name 0)
if [ ! -f $fallback ]; then
    printf -v err "Missing fallback action script: %s\n       The file can be empty, but must exist!" "$fallback"
    error_exit "$err"
fi

read_config "$CONFIG"

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

[ "$GUID" ] || exit_required 'Channel GUID' GUID

RANGE_N=$(int "$RANGE_N")
[ $RANGE_N -gt 0 ] || exit_required Ranges RANGE_N

### Read back at least 1 minute
MINUTES=$(int "$MINUTES")
[ $MINUTES -gt 0 ] || MINUTES=1

##############################################################################
### Go
##############################################################################
lastkey=$(key_name react "$CONFIG" last)
timekey=$(key_name react "$CONFIG" time)

### Fetch data
data=$(PVLngGET "data/$GUID.tsv?start=-${MINUTES}minutes&period=last")

if [ "$data" ]; then
    set -- $data
    timestamp=$1
    value=$2
fi

lkv 1 Value "$value"

last=$(PVLngStoreGET $lastkey 0)

if [ -z "$value" ]; then
    ### 1st time: $last <> 0; do nothing if still 0
    if [ $last -ne 0 ]; then
        log 1 "No value found, fallback"
        doAction 0
        echo -n 0 >$lastfile
    fi
    exit
fi

### Analyse value ranges

i=0

while [ $i -lt $RANGE_N ]; do

    i=$((i+1))

    sec 1 $i

    ### Check section variables
    var1 LOWER $i
    [ "$LOWER" ] || exit_required 'Lower limit' LOWER_$i

    var1 UPPER $i
    [ "$UPPER" ] || exit_required 'Upper limit' UPPER_$i

    [ $(calc "$LOWER < $UPPER" 0) -eq 1 ] || \
    error_exit "Lower limit must be lower than upper limit (LOWER_$i, UPPER_$i)"

    ### Correct limits range found?
    check=$(calc "($LOWER < $value) && ($value <= $UPPER)" 0)
    lkv 1 Condition "$LOWER < $value <= $UPPER"
    lkb 1 Match $check

    [ $check -eq 1 ] || continue

    ### Check for range change, exit if same as before
    if [ ! "$FORCE" -a $last -eq $i ]; then
        log 1 "Same as on last run, nothing to do"
        break
    fi

    ### Check last action active time
    duetime=$(PVLngStoreGET $timekey 0)

    if [ $(calc "$duetime > $REQUEST_TIME" 0) -eq 1 ]; then
        var1 OVERRULE $i
        ### Check overrule last active action, overrules fallback always
        if echo ",0,$OVERRULE," | grep -q ",$last,"; then
            ### Over rule allowed, go on
            log 1 "Action $i will overrule last action $last, abort last action"
        else
            ### No over rule, exit
            log 1 "Last action $last will be active until "$(date -d @$duetime)
            log 1 "Action $i will NOT overrule this, skip and wait"
            break
        fi
    fi

    doAction $i

    if [ -z "$TEST" ]; then
        var1int MINTIME $i 0
        PVLngStorePUT $timekey $(calc "$(now) + $MINTIME * 60" 0)
        PVLngStorePUT $lastkey $i
    fi

    ### Skip further checks
    break
done
