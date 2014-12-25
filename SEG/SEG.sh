#!/bin/bash
##############################################################################
### @author     Knut Kohl <github@knutkohl.de>
### @copyright  2012-2014 Knut Kohl
### @license    MIT License (MIT) http://opensource.org/licenses/MIT
### @version    1.0.0
##############################################################################

APIURL="http://api.smartenergygroups.com/api_sites/stream"

##############################################################################
### Init
##############################################################################
source $(dirname $0)/../PVLng.sh

### Script options
opt_help      "Update Smart Energy Group streams for one device"
opt_help_args "<config file>"
opt_help_hint "See dist/device.conf for details."

opt_define short=i long=interval variable=INTERVAL desc='Fix Average interval in minutes'

### PVLng default options
opt_define_pvlng

source $(opt_build)

read_config "$1"

##############################################################################
### Start
##############################################################################
test "$TRACE" && set -x

test "$SITE_TOKEN" || error_exit "SEG site name is required (SITE_TOKEN)"
test "$NODE_NAME" || error_exit "SEG node name is required (NODE_NAME)"

STREAM_N=$(int "$STREAM_N")
test $STREAM_N -gt 0 || error_exit "No stream sections defined (STREAM_N)"

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

log 1 "Interval : $INTERVAL"

i=0

while [ $i -lt $STREAM_N ]; do

    i=$((i+1))

    sec 1 Stream $i

    var1 STREAM $i
    if [ -z "$STREAM" ]; then
        log 1 "Missing STREAM $i, disabled"
        continue
    fi
    lkv 2 STREAM "$STREAM"

    var1 GUID $i
    [ "$GUID" ] || error_exit "Missing GUID (GUID_$i)"
    lkv 2 GUID $GUID

#    PVLngChannelAttr $GUID meter

#    if test $meter -eq 1; then
#        fetch="start=midnight&period=1d"
#    else
        ### Fetch for sensor channels average of last x minutes
        fetch="start=-${INTERVAL}minutes&period=${INTERVAL}minutes"
#    fi

    ### read value, get last row
    row=$(PVLngGET data/$GUID.tsv?$fetch | tail -n1)
    lkv 2 Data "$row"

    ### No data for last $INTERVAL minutes
    test "$row" || continue

    if echo "$row" | egrep -q '[[:alpha:]]'; then
        error_exit "PVLng API readout error:\n$row"
    fi

    ### set "data" to $2
    set $row
    value="$2"

    PVLngChannelAttr $GUID numeric

    ### Factor for this channel
    if test $numeric -eq 1; then
        ### Only for numeric channels!
        var1 FACTOR $i
        lkv 2 Factor $FACTOR
        [ "$FACTOR" ] && value=$(calc "$value * $FACTOR")
    else
        ### URL encode spaces to +
        value="$(echo $value | sed -e 's~ ~+~g')"
    fi

    lkv 1 Value $value

    stream_data="$stream_data($STREAM $value)"

done

test "$stream_data" || exit

data="(site $SITE_TOKEN (node $NODE_NAME ? $stream_data))"

lkv 2 Send "$data"

test "$TEST" && exit

### Send
rc=$($(curl_cmd) --request PUT --write-out %{http_code} \
                 --output $TMPFILE --data "$data" $APIURL)

log 2 "API response:"
log 2 @$TMPFILE

### Check result, ONLY 200 is ok
if test $rc -eq 200; then
    ### Ok, state added
    log 1 "Ok"
else
    ### log error
    save_log "SEG-$NODE_NAME" "Update failed [$rc] for $value"
    save_log "SEG-$NODE_NAME" @$TMPFILE
fi

set +x
