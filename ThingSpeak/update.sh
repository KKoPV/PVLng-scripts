#!/bin/sh
##############################################################################
### @author     Knut Kohl <github@knutkohl.de>
### @copyright  2012-2014 Knut Kohl
### @license    MIT License (MIT) http://opensource.org/licenses/MIT
### @version    1.0.0
##############################################################################

APIURL='https://api.thingspeak.com/update'

##############################################################################
### Init
##############################################################################
source $(dirname $0)/../PVLng.sh

### Script options
opt_help      "Update ThingSpeak channel"
opt_help_args "<config file>"
opt_help_hint "See dist/channel.conf for details."

opt_define short=i long=interval variable=INTERVAL desc='Fix Average interval in minutes'

### PVLng default options
opt_define_pvlng

source $(opt_build)

read_config "$1"

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

[ "$APIURL" ] || error_exit "ThingSpeak API URL is required, see ThingSpeak.conf.dist"
[ "$APIKEY" ] || error_exit "ThingSpeak channel API Write key is required (APIKEY)"

FIELD_N=$(int "$FIELD_N")
[ $FIELD_N -gt 0 ] || error_exit "No field sections defined (FIELD_N)"

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

    sec 1 Field $i

    var1 GUID $i
    [ "$GUID" ] || error_exit "Missing GUID (GUID_$i)"
    lkv 2 GUID $GUID

    ### Fetch for sensor channels average of last x minutes
    fetch="start=-${INTERVAL}minutes&period=${INTERVAL}minutes"

    ### Read value, get last row
    row=$(PVLngGET data/$GUID.tsv?$fetch | tail -n1)
    lkv 2 Data "$row"

    ### No data for last $INTERVAL minutes
    [ "$row" ] || continue

    ### Set "data" to $2
    set $row
    value="${2:-<empty>}"

    PVLngChannelAttr $GUID numeric

    ### Factor for this channel, only for numeric channels!
    if [ $numeric -eq 1 ]; then
        var1 FACTOR $i
        lkv 2 Factor ${FACTOR:=1} # Set to 1 if not defined
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
if [ $rc -gt 0 ]; then
    ### Ok, state added
    log 1 "Ok"
else
    ### log error
    save_log "ThingSpeak" "Update failed for $data"
    save_log "ThingSpeak" @$TMPFILE
fi

set +x
