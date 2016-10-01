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

### ThingSpeak API URL
APIURL='https://api.thingspeak.com/update'

##############################################################################
### Init
##############################################################################
. $pwd/../PVLng.sh

### Script options
opt_help      "Update ThingSpeak channel"
opt_help_hint "See dist/thingspeak.conf for details."

opt_define short=i long=interval variable=INTERVAL \
           desc='Fix Average interval in minutes'

### PVLng default options
opt_define_pvlng

. $(opt_build)

daemonize

read_config "$CONFIG"

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

check_required APIURL 'ThingSpeak channel API URL'
check_required APIKEY 'ThingSpeak channel API Write key'

[ $(int $DAEMONIZE) -gt 0 ] && INTERVAL=$(calc "$DAEMONIZE / 60" 0)

##############################################################################
### Go
##############################################################################
while true; do

    t=$(now)

    if [ -z "$INTERVAL" ]; then
        NOW=$(date +%s)
        ifile=$(run_file ThingSpeak "$CONFIG" last)
        if [ -s "$ifile" ]; then
            INTERVAL=$(calc "($NOW - $(<$ifile)) / 60" 0)
        else
            ### Start with 10 minutes
            INTERVAL=10
        fi
        ### Remember actual timestamp
        [ "$TEST" ] || echo $NOW >$ifile
    fi

    lkv 1 Interval $INTERVAL

    data="-d api_key=$APIKEY"

    for i in $(getGUIDs); do

        sec 1 $i

        ### If not USE is set, set to $i
        var1 USE $i $i
        var1 GUID $USE

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

        data="$data -d field$i=$value"

    done

    [ "$data" ] || exit

    sec 1 Send

    lkv 2 Send "$data"

    [ "$TEST" ] && exit

    ### Send
    rc=$($(curl_cmd) -X POST $data $APIURL)

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

    daemonize_check $t

done
