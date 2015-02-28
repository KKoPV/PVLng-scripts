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

### SEG API URL
APIURL="http://api.smartenergygroups.com/api_sites/stream"

##############################################################################
### Init
##############################################################################
. $pwd/../PVLng.sh

### Script options
opt_help      "Update Smart Energy Group streams for one device"
opt_help_args "<config file>"
opt_help_hint "See dist/device.conf for details."

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

check_required SITE_TOKEN 'SEG site name'
check_required NODE_NAME 'SEG node name'

STREAM_N=$(int "$STREAM_N")
[ $STREAM_N -gt 0 ] || exit_required "Stream sections" STREAM_N

##############################################################################
### Go
##############################################################################
curl=$(curl_cmd)

if [ -z "$INTERVAL" ]; then
    ifile=$(run_file SEG "$1" last)
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

while [ $i -lt $STREAM_N ]; do

    i=$((i+1))

    sec 1 $i

    var1 STREAM $i
    [ -z "$STREAM" ] && log 1 Skip && continue

    var1 GUID $i
    [ -z "$GUID" ] && log 1 Skip && continue

    ### read value, get last row
    row=$(PVLngGET "data/$GUID.tsv?start=-${INTERVAL}minutes&period=${INTERVAL}minutes" | tail -n1)
    lkv 2 Data "$row"

    ### No data for last $INTERVAL minutes
    [ "$row" ] || continue

    if echo "$row" | egrep -q '[[:alpha:]]'; then
        error_exit "PVLng API readout error:\n$row"
    fi

    ### set "data" to $2
    set -- $row
    value="$2"

    PVLngChannelAttr $GUID numeric

    ### Factor for this channel
    if [ $numeric -eq 1 ]; then
        ### Only for numeric channels!
        var1 FACTOR $i 1
        lkv 2 Factor $FACTOR
        value=$(calc "$value * $FACTOR")
    else
        ### URL encode spaces to +
        value="$(echo $value | sed -e 's~ ~+~g')"
    fi

    lkv 1 Value $value

    stream_data="$stream_data($STREAM $value)"
done

[ "$stream_data" ] || exit

data="(site $SITE_TOKEN (node $NODE_NAME ? $stream_data))"

lkv 2 Send "$data"

[ "$TEST" ] && exit

### Send
rc=$($(curl_cmd) --request PUT --write-out %{http_code} \
                 --output $TMPFILE --data "$data" $APIURL)

log 2 @$TMPFILE "API response"

### Check result, ONLY 200 is ok
if [ $rc -eq 200 ]; then
    ### Ok, state added
    log 1 "Ok"
else
    ### log error
    save_log "SEG-$NODE_NAME" "Update failed [$rc] for $value"
    save_log "SEG-$NODE_NAME" @$TMPFILE
fi

set +x
