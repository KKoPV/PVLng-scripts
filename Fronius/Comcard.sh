#!/bin/bash
##############################################################################
### @author      Knut Kohl <github@knutkohl.de>
### @copyright   2012-2013 Knut Kohl
### @license     GNU General Public License http://www.gnu.org/licenses/gpl.txt
### @version     1.0.0
##############################################################################

##############################################################################
### Init variables
##############################################################################
pwd=$(dirname $0)

source $pwd/../PVLng.sh

### Script options
opt_help      "Read data from Fronius inverters/SensorCards"
opt_help_args "<config file>"
opt_help_hint "See dist/Comcard.conf for details."

### PVLng default options with flag for save data
opt_define_pvlng x

source $(opt_build)

read_config "$1"

##############################################################################
### Init
##############################################################################
[ "$APIURL" ] || error_exit "Solar Net API URL is required (APIURL)"

GUID_N=$(int "$GUID_N")
[ $GUID_N -gt 0 ]|| error_exit "No GUIDs defined (GUID_N)"

daylight=$(PVLngGET "daylight/60.txt")
log 2 "Daylight: $daylight"
[ $daylight -eq 1 ] || exit 127

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

##############################################################################
### Go
##############################################################################
### Process the request, $1 - Request, $2 - DataCollection, $3 - DeviceId
function requestComCard {

    url="$APIURL/$1.cgi?Scope=Device&DataCollection=$2&DeviceId=$3"
    log 2 "$url"

    ### Empty response file
    echo -n >$RESPONSEFILE
    $curl --output $RESPONSEFILE $url
    rc=$?

    [ $rc -ne 0 ] && curl_error_exit $rc "$1/$2/$3"

    ### Test mode
    log 2 "$1 response:"
    log 2 @$RESPONSEFILE

    ### Save data
    [ "$TEST" ] || PVLngPUT $GUID @$RESPONSEFILE

}

RESPONSEFILE=$(temp_file)

curl="$(curl_cmd --header 'Content-Type=application/json')"

i=0

while test $i -lt $GUID_N; do

    i=$((i+1))

    sec 1 $i

    var1 GUID $i
    [ "$GUID" ] || error_exit "Inverter GUID is required (GUID_$i)"

    ### Request serial and type, required fields
    PVLngChannelAttr $GUID SERIAL
    PVLngChannelAttr $GUID CHANNEL

    if [ $CHANNEL -eq 1 -o $CHANNEL -eq 2 ]; then
        requestComCard GetInverterRealtimeData CommonInverterData $SERIAL
    fi

    if [ $CHANNEL -eq 2 ]; then
        requestComCard GetStringRealtimeData NowStringControlData $SERIAL
    fi

    if [ $CHANNEL -eq 3 ]; then
        requestComCard GetSensorRealtimeData NowSensorData $SERIAL
    fi

done
