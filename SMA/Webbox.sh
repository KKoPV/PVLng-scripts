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

### Default Webbox IP
_WEBBOX=192.168.0.168:80

##############################################################################
### Init
##############################################################################
. $pwd/../PVLng.sh

### Script options
opt_help      "Read Inverter or Sensorbox data from a SMA Webbox"
opt_help_args "<config file>"
opt_help_hint "See dist/Webbox.conf for details."

### PVLng default options with flag for save data
opt_define_pvlng x

. $(opt_build)

CONFIG=$1

read_config "$CONFIG"

### Run only during daylight +- 60 min
check_daylight 60

check_lock $(basename $1)

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

check_default WEBBOX $_WEBBOX

GUID_N=$(int "$GUID_N")
[ $GUID_N -gt 0 ] || exit_required Sections GUID_N

##############################################################################
### Go
##############################################################################
temp_file RESPONSEFILE

curl="$(curl_cmd)"

### Check for provided installer password
if [ "$PASSWORD" ]; then
    set -- $(echo -n "$PASSWORD" | md5sum)
    PASSWORD=',"passwd":"'$1'"'
fi

i=0

while [ $i -lt $GUID_N ]; do

    i=$((i+1))

    sec 1 $i

    var1 GUID $i
    [ -z "$GUID" ] && log 1 Skip && continue

    var1 SERIAL $i
    if [ -z "$SERIAL" ]; then
        ### Read from API
        PVLngChannelAttr $GUID SERIAL
    fi
    [ "$SERIAL" ] || error_exit "No serial number found for GUID: $GUID"
    lkv 1 "Use SERIAL" "$SERIAL"

    ### Build RPC request, catch all channels from equipment
    ### Response JSON holds no timestamp, use "id" paramter for this,
    ### relevant for loading failed data
    cat <<EOT >$TMPFILE
{"version":"1.0","proc":"GetProcessData","id":"$(date +%s)","format":"JSON","params":{"devices":[{"key":"$SERIAL"}]}$PASSWORD}
EOT

    log 2 @$TMPFILE "Webbox request"

    ### Query webbox
    $curl --output $RESPONSEFILE --data-urlencode RPC@$TMPFILE http://$WEBBOX/rpc
    rc=$?

    [ $rc -eq 0 ] || error_exit "cUrl error for Webbox: $rc"

    ### Test mode
    log 2 @$RESPONSEFILE "Webbox response"

    ### Check response for error object
    if grep -q '"error"' $RESPONSEFILE; then
        error_exit "$(printf "ERROR from Webbox:\n%s" "$(<$RESPONSEFILE)")"
    fi

    ### Save data
    PVLngPUT $GUID @$RESPONSEFILE

done
