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
WEBBOX=192.168.0.168:80

##############################################################################
### Init
##############################################################################
. $pwd/../PVLng.sh

### Script options
opt_help      "Read Inverter or Sensorbox data from a SMA Webbox"
opt_help_hint "See dist/Webbox.conf for details."

### PVLng default options with flag for save data
opt_define_pvlng x

. $(opt_build)

daemonize

read_config "$CONFIG"

#check_lock $(basename $CONFIG)

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

check_required WEBBOX 'Webbox IP'

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

while true; do

    t=$(now)

    ### Run only during daylight +- 60 min
    if [ $(check_daylight 60 yes) -eq 1 ]; then

        for i in $(getGUIDs); do

            sec 1 $i

            ### If not USE is set, set to $i
            var1 USE $i $i
            var1 GUID $USE

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
            echo '{"version":"1.0","proc":"GetProcessData","id":"'$(date +%s)'","format":"JSON","params":{"devices":[{"key":"'$SERIAL'"}]}'$PASSWORD'}' >$TMPFILE

            log 2 @$TMPFILE "Webbox request"

            ### Query webbox
            $curl --output $RESPONSEFILE --data-urlencode RPC@$TMPFILE http://$WEBBOX/rpc
            rc=$?

            [ $rc -eq 0 ] || curl_error_exit $rc Webbox

            log 2 @$RESPONSEFILE "Webbox response"

            ### Check response for error object
            if grep -q '"error"' $RESPONSEFILE; then
                error_exit "$(printf "ERROR from Webbox:\n%s" "$(<$RESPONSEFILE)")"
            fi

            ### Save data
            PVLngPUT $GUID @$RESPONSEFILE

        done

    fi

    daemonize_check $t

done
