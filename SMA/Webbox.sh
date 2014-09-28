#!/bin/bash
##############################################################################
### @author      Knut Kohl <github@knutkohl.de>
### @copyright   2012-2014 Knut Kohl
### @license     MIT License (MIT) http://opensource.org/licenses/MIT
### @version     1.0.0
##############################################################################

##############################################################################
### Init
##############################################################################

. $(dirname $0)/../PVLng.sh

### Script options
opt_help      "Read Inverter or Sensorbox data from SMA Webbox"
opt_help_args "<config file>"
opt_help_hint "See Webbox.conf.dist for details."

### PVLng default options with flag for save data
opt_define_pvlng x

. $(opt_build)

### Don't check lock file in test mode
[ "$TEST" ] || check_lock $(basename $1)

WEBBOX='192.168.0.168:80'

read_config "$1"

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

[ "$WEBBOX" ] || error_exit "IP address is required!"

GUID_N=$(int "$GUID_N")
[ $GUID_N -gt 0 ] || error_exit "No GUIDs defined (GUID_N)"

##############################################################################
### Go
##############################################################################
RESPONSEFILE=$(temp_file)
on_exit_rm $RESPONSEFILE

curl="$(curl_cmd)"

### Run only during daylight +- 60 min
daylight=$(PVLngGET "daylight/60.txt")
log 2 "Daylight: $daylight"
[ $daylight -eq 1 ] || exit 127

[ "$PASSWORD" ] && PASSWORD=',"passwd":"'$(echo -n "$PASSWORD" | md5sum | cut -d' ' -f1)'"'

i=0

while [ $i -lt $GUID_N ]; do

    i=$((i+1))

    log 1 "--- $i ---"

    var1 GUID $i
    if [ -z "$GUID" ]; then
        log 1 Disabled, skip
        continue
    fi

    var1 SERIAL $i
    if [ -z "$SERIAL" ]; then
        ### Read from API
        PVLngChannelAttr $GUID SERIAL
    fi
    [ "$SERIAL" ] || error_exit "No serial number found for GUID: $GUID"

    ### Build RPC request, catch all channels from equipment
    ### Response JSON holds no timestamp, use "id" paramter for this,
    ### relevant for loading failed data
    cat >$TMPFILE <<EOT
{"version":"1.0","proc":"GetProcessData","id":"$(date +%s)","format":"JSON","params":{"devices":[{"key":"$SERIAL"}]}$PASSWORD}
EOT

    log 2 "Webbox request:"
    log 2 @$TMPFILE

    ### Query webbox
    $curl --output $RESPONSEFILE --data-urlencode RPC@$TMPFILE http://$WEBBOX/rpc
    rc=$?

    [ $rc -eq 0 ] || error_exit "cUrl error for Webbox: $rc"

    ### Test mode
    log 2 "Webbox response:"
    log 2 @$RESPONSEFILE

    ### Check response for error object
    if grep -q '"error"' $RESPONSEFILE; then
        error_exit "$(printf "ERROR from Webbox:\n%s" "$(<$RESPONSEFILE)")"
    fi

    ### Save data
    [ "$TEST" ] || PVLngPUT $GUID @$RESPONSEFILE

done
