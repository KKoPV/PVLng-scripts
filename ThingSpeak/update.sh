#!/bin/bash
##############################################################################
### @author     Knut Kohl <github@knutkohl.de>
### @copyright  2012-2015 Knut Kohl
### @license    MIT License (MIT) http://opensource.org/licenses/MIT
### @version    1.0.0
##############################################################################

##############################################################################
### Constants
##############################################################################
pwd=$(dirname $0)

### ThingSpeak API URL
_APIURL='https://api.thingspeak.com/update'

##############################################################################
### Init
##############################################################################
. $pwd/../PVLng.sh

### Script options
opt_help      "Update ThingSpeak channel"
opt_help_args "<config file>"
opt_help_hint "See dist/channel.conf for details."

opt_define short=i long=interval variable=INTERVAL desc='Fix Average interval in minutes'

### PVLng default options
opt_define_pvlng

. $(opt_build)

CONFIG=$1

read_config "$CONFIG"

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

check_default APIURL $_APIURL
check_required APIKEY 'ThingSpeak channel API Write key'

FIELD_N=$(int "$FIELD_N")
[ $FIELD_N -gt 0 ] || exit_required "Field sections" FIELD_N

##############################################################################
### Go
##############################################################################
if [ -z "$INTERVAL" ]; then
    ifile=$(run_file ThingSpeak "$1" last)
    if [ -s "$ifile" ]; then
        INTERVAL=$(calc "($(date +%s) - $(<$ifile)) / 60" 0)
    else
        ### Start with 10 minutes
        INTERVAL=10
    fi
    ### Remember actual timestamp
    date +%s >$ifile
fi

lkv 1 Interval $INTERVAL

i=0

while [ $i -lt $FIELD_N ]; do

    i=$((i+1))

    sec 1 $i

    var1 GUID $i
    [ -z "$GUID" ] && log 1 Skip && continue

    ### Fetch for sensor channels average of last x minutes
    fetch="start=-${INTERVAL}minutes&period=${INTERVAL}minutes"

    ### Read data, get last row
    set -- $(PVLngGET "data/$GUID.tsv?$fetch" | tail -n1)

    [ "$1" ] || continue

    value="${2:-<empty>}"

    PVLngChannelAttr $GUID NUMERIC

    ### Factor for this channel, only for numeric channels!
    if [ $NUMERIC -eq 1 ]; then
        var1 FACTOR $i 1
        value=$(calc "$value * $FACTOR")
    fi

    lkv 1 Value $value

    data="$data&$i=$value"

done

[ "$data" ] || exit

sec 1 Send

data="key=$APIKEY$data"
lkv 2 Send "$data"

[ "$TEST" ] && exit

### Send
rc=$($(curl_cmd) --data "$data" $APIURL)

lkv 2 "API response" $rc

### Check result, ONLY not zero is ok
if [ "$rc" -a $rc -gt 0 ]; then
    ### Ok, state added
    log 1 "Ok"
else
    ### log error
    save_log "ThingSpeak" "Update failed for $data"
    save_log "ThingSpeak" @$TMPFILE
fi

set +x
