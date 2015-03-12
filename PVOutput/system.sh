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

### URL to get system info
GetSystemURL=http://pvoutput.org/service/r2/getsystem.jsp

### URL to add system status
AddStatusURL=http://pvoutput.org/service/r2/addstatus.jsp

### How many parameters are supported
vMax=12

##############################################################################
### Functions
##############################################################################
function readSystem {
    log 1 "Fetch System infos for system Id $SYSTEMID"
    ### Extract status interval from response, 16th value
    ### http://pvoutput.org/help.html#api-getsystem
    INTERVAL=$($(curl_cmd) --header "X-Pvoutput-Apikey: $APIKEY" \
                           --header "X-Pvoutput-SystemId: $SYSTEMID" \
                           $GetSystemURL | cut -d';' -f1 | cut -d',' -f16)
    ### Store only valid status interval
    [ $(int "$INTERVAL") -gt 0 ] && PVLngStorePUT $intervalkey $INTERVAL
}

##############################################################################
### Init
##############################################################################
. $pwd/../PVLng.sh

### Script options
opt_help      "Update a system on PVOutput.org"
opt_help_args "<config file>"
opt_help_hint "See dist/system.conf for details."

opt_define short=r long=read desc="Force re-read system information (after update on pvoutput.org)" variable=REREAD value=y

### PVLng default options
opt_define_pvlng

. $(opt_build)

CONFIG=$1

read_config "$1"

intervalkey=$(key_name PVOutput "$CONFIG" interval)

if [ "$REREAD" ]; then
    readSystem
    exit
fi

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

check_required APIKEY 'API key'
check_required SYSTEMID 'Plant Id'

##############################################################################
### Go
##############################################################################
### Get system status interval
INTERVAL=$(PVLngStoreGET $intervalkey)
### Read system info on first run
[ "$INTERVAL" ] || readSystem

lkv 2 Interval "$INTERVAL min."

DATA=
i=0
check=

while [ $i -lt $vMax ]; do

    i=$((i+1))

    sec 1 v$i

    var1 GUID $i

    if [ "$GUID" ]; then
  
        var1 FACTOR $i 1

        ### empty temp. file
        >$TMPFILE

        set -- $(PVLngGET data/$GUID.tsv?period=${INTERVAL}minute | tail -n1)
        value=$2

        ### unset only zero values for v1 .. v4
        [ $i -le 4 -a "$value" = "0" ] && value=

        if [ "$value" ]; then
            value=$(calc "$value * $FACTOR")
            DATA="$DATA -d v$i=$value"
        fi
        lkv 1 Value $value

        check="$check$value"
    fi

    ### Check if at least one of v1...v4 is set
    if [ $i -eq 4 ]; then
        if [ "$check" ]; then
            sec 1 OK
            log 1 At least one of v1 .. v4 is filled correctly
        else
            ### skip further processing
            sec 1 SKIP
            log 1 All of v1 .. v4 are empty!
            exit
        fi
    fi

done

DATA="-d d="$(date "+%Y%m%d")" -d t="$(date "+%H:%M")"$DATA"

sec 1 Data $DATA

[ "$TEST" ] && exit

#save_log "PVOutput" "$DATA"

### Send
$(curl_cmd) --header "X-Pvoutput-Apikey: $APIKEY" \
            --header "X-Pvoutput-SystemId: $SYSTEMID" \
            --output $TMPFILE $DATA $AddStatusURL
rc=$?

log 1 @$TMPFILE

### Check curl exit code
[ $rc -eq 0 ] || curl_error_exit $rc "$DATA"

### Check result, ONLY 200 is ok
if cat $TMPFILE | grep -qv '200:'; then
    ### log error
    save_log "PVOutput" "$SYSTEMID - Update failed: $(cat $TMPFILE)"
    save_log "PVOutput" "$SYSTEMID - Data: $DATA"
fi
