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

### Hidden option to test also outside daylight times
opt_define short=f long=force variable=FORCE value=y

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
curl="$(curl_cmd)"

### Check for provided installer password
if [ "$PASSWORD" ]; then
    set -- $(echo -n "$PASSWORD" | md5sum)
    PASSWORD=',"passwd":"'$1'"'
fi

while true; do

    t=$(now)

    ### Run only during daylight +- 60 min
    if [ "$FORCE" -o $(check_daylight 60 yes) -eq 1 ]; then

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
            $curl --output $TMPFILE --data-urlencode RPC@$TMPFILE http://$WEBBOX/rpc
            rc=$?

            if [ $rc -ne 0 ]; then
                if [ grep -q "$rc," <<<"$CURLIGNORE," ]; then
                    ### Exit with error message only if not an ignored error
                    curl_error_exit $rc Webbox
                fi
                exit
            fi

            log 2 @$TMPFILE "Webbox response"

            ### Check response for error object
            if grep -q '"error"' $TMPFILE; then
                error_exit "$(printf "ERROR from Webbox:\n%s" "$(<$TMPFILE)")"
            fi

            ### Save data
            PVLngPUT $GUID @$TMPFILE

        done

    fi

    daemonize_check $t

done
