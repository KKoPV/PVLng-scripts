#!/bin/bash
##############################################################################
### @author      Knut Kohl <github@knutkohl.de>
### @copyright   2012-2015 Knut Kohl
### @license     GNU General Public License http://www.gnu.org/licenses/gpl.txt
### @version     $Id$
##############################################################################

##############################################################################
### Constants
##############################################################################
pwd=$(dirname $0)

### API URL with placeholders
APIURL='https://api.xively.com/v2/feeds/$FEED'

##############################################################################
### Init
##############################################################################
. $pwd/../PVLng.sh

### Script options
opt_help      "Push PVLng channel data to device channels on Xively.com"
opt_help_hint "See dist/xively.conf for details."

### PVLng default options
opt_define_pvlng

. $(opt_build)

read_config "$CONFIG"

##############################################################################
### Check config data
##############################################################################
check_required FEED   'Xively feed'
check_required APIKEY 'Xively API key'

GUID_N=$(int "$GUID_N")
[ $GUID_N -gt 0 ] || exit_required Sections GUID_N

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

NOW=$(date +%s)
LASTFILE=$(run_file xively "$CONFIG")

if [ -f "$LASTFILE" ]; then
    LAST=$(<$LASTFILE)
else
    ### Start 10 min. before
    LAST=$(calc "$NOW - 600" 0)
fi

INTERVAL=$(calc "($NOW - $LAST) / 60" 0)
echo $NOW >$LASTFILE

eval APIURL="$APIURL"
lkv 2 'API Endpoint' $APIURL

curl=$(curl_cmd)
i=0
found=

while [ $i -lt $GUID_N ]; do

    i=$((i + 1))

    sec 1 $i

    ### required parameters
    var1 GUID $i
    [ -z "$GUID" ] && log 1 Skip && continue

    var1 CHANNEL $i
    if [ -z "$CHANNEL" ]; then
        ### Read from API
        PVLngChannelAttr $GUID CHANNEL
    fi
    [ "$CHANNEL" ] || error_exit "Xively channel name is required (CHANNEL_$i)"

    ### read value, get last row
    row=$(PVLngGET "data/$GUID.tsv?start=-${INTERVAL}minutes&period=${INTERVAL}minutes" | tail -n1)
    lkv 2 Data "$row"

    ### Just after 0:00 no data for today yet
    [ "$row" ] || continue

    if echo "$row" | egrep -q '[[:alpha:]]'; then
        error_exit "$row"
    fi

    ### set timestamp and data to $1 and $2
    set -- $row
    timestamp=$1

    ### Format for this channel defined?
    var1 FORMAT $i

    if [ "$FORMAT" ]; then
        value=$(printf "$FORMAT" "$2")
    else
        value=$2
    fi

    age=$(calc "($NOW - $timestamp) / 60" 0)
    lkv 2 Last "$(date -d @$timestamp)"
    lkv 2 Age  "$age min."

    ### test for valid timestamp
    if [ $age -gt $INTERVAL ]; then
        log 1 "Skip timestamp outside update interval."
        continue
    fi

    lkv 1 Value "$value"

    echo "$CHANNEL,$value" >>$TMPFILE

    found=y

done

### found at least one "active" channel
[ "$found" ] || exit

sec 2 "Send data" "$(<$TMPFILE)"

[ "$TEST" ] && exit

temp_file _RESPONSE

### Send
set $($curl --request PUT --write-out %{http_code} --header "X-ApiKey: $APIKEY" \
            --output $_RESPONSE --data-binary @$TMPFILE $APIURL.csv)

### Check result, ONLY 200 is ok
if [ $1 -eq 200 ]; then
    ### Ok, data added
    lkv 1 "HTTP code" $1
    [ -s $_RESPONSE ] && log 2 @$_RESPONSE Response
else
    ### log error
    save_log "Xively" "Failed: $(<$TMPFILE)"
fi

set +x
