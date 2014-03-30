#!/bin/bash
##############################################################################
### @author      Knut Kohl <github@knutkohl.de>
### @copyright   2012-2014 Knut Kohl
### @license     GNU General Public License http://www.gnu.org/licenses/gpl.txt
### @version     1.0.0
##############################################################################

##############################################################################
### Init
##############################################################################
pwd=$(dirname $0)

. $pwd/../PVLng.conf
. $pwd/../PVLng.sh

while getopts "i:tvxh" OPTION; do
    case "$OPTION" in
        i) INTERVAL=$(int "$OPTARG") ;;
        t) TEST=y; VERBOSE=$((VERBOSE + 1)) ;;
        v) VERBOSE=$((VERBOSE + 1)) ;;
        x) TRACE=y ;;
        h) usage; exit ;;
        ?) usage; exit 1 ;;
    esac
done

read_config $pwd/SEG.conf

shift $((OPTIND-1))

read_config "$1"

##############################################################################
### Start
##############################################################################
test "$TRACE" && set -x

test "$APIURL" || error_exit "SEG API URL is required, see SEG.conf.dist"
test "$SITE_TOKEN" || error_exit "SEG site name is required (SITE_TOKEN)"
test "$NODE_NAME" || error_exit "SEG node name is required (NODE_NAME)"

STREAM_N=$(int "$STREAM_N")
test $STREAM_N -gt 0 || error_exit "No stream sections defined (STREAM_N)"

##############################################################################
### Go
##############################################################################
curl=$(curl_cmd)

if test -z "$INTERVAL"; then
    ifile=$(run_file SEG "$1" last)
    if test -f "$ifile"; then
        INTERVAL=$(echo "scale=0; ( "$(date +%s)" - "$(<$ifile)" ) / 60" | bc -l)
    else
        ### Start with 10 minutes
        INTERVAL=10
    fi
    ### Remember actual timestamp
    date +%s >$ifile
fi

i=0

while test $i -lt $STREAM_N; do

    i=$((i + 1))

    log 1 "--- GUID $i ---"

    var1 GUID $i
    if test -z "$GUID"; then
        log 1 "Missing GUID $i, disabled"
        continue
    fi

    log 2 "GUID     : $GUID"

    ### Required parameters
    var1 STREAM_NAME $i
    test "$STREAM_NAME" || error_exit "SEG stream name is required (STREAM_NAME_$i)"
    log 2 "STREAM   : $STREAM_NAME"

    ### Buffer meter attribute
    mfile=$(run_file SEG $GUID meter)
    if test -f "$mfile"; then
        meter=$(<$mfile)
    else
        meter=$(int $(PVLngGET channel/$GUID/meter.txt))
        echo -n $meter >$mfile
    fi

#    if test $meter -eq 1; then
#        fetch="start=midnight&period=1d"
#    else
        ### Fetch for sensor channels average of last x minutes
        fetch="start=-${INTERVAL}minutes&period=${INTERVAL}minutes"
#    fi

    ### read value, get last row
    row=$(PVLngGET data/$GUID.tsv?$fetch | tail -n1)
    log 2 "Data:    : $row"

    ### No data for last $INTERVAL minutes
    test "$row" || continue

    if echo "$row" | egrep -q '[[:alpha:]]'; then
        error_exit "PVLng API readout error:\n$row"
    fi

    ### set "data" to $2
    set $row
    value="$2"

    ### Buffer numeric attribute
    nfile=$(run_file SEG $GUID numeric)
    if test -f "$nfile"; then
        numeric=$(<$nfile)
    else
        numeric=$(int $(PVLngGET channel/$GUID/numeric.txt))
        echo -n $numeric >$nfile
    fi

    ### Factor for this channel
    if test $numeric -eq 1; then
        ### Only for numeric channels!
        var1 FACTOR $i
        log 2 "Factor   : $FACTOR"
        test "$FACTOR" && value=$(echo "scale=4; $value * $FACTOR" | bc -l)
    else
        ### URL encode spaces to +
        value="$(echo $value | sed -e 's~ ~+~g')"
    fi

    log 1 "Value    : $value"

    stream_data="$stream_data($STREAM_NAME $value)"

done

test "$stream_data" || exit

data="(site $SITE_TOKEN (node $NODE_NAME ? $stream_data))"

log 2 "Send     : $data"

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

exit

##############################################################################
# USAGE >>

Update Smart Energy Group streams for one device

Usage: $scriptname [options] config_file

Options:
    -i interval  Fix Average interval in minutes
    -t           Test mode, don't push to SEG
                 Sets verbosity to info level
    -v           Set verbosity level to info level
    -vv          Set verbosity level to debug level
    -h           Show this help

See device.conf.dist for reference.

# << USAGE
