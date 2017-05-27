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

##############################################################################
### Functions
##############################################################################
requestComCard () {
    ### $1 - Request
    ### $2 - DataCollection

    url="$APIURL/$1.cgi?Scope=Device&DataCollection=$2&DeviceId=$SERIAL"
    log 2 "$url"

    ### Empty response file
    >$RESPONSEFILE

    $curl --output $RESPONSEFILE $url
    rc=$?

    [ $rc -ne 0 ] && curl_error_exit $rc "$1/$2/$3"

    log 2 @$RESPONSEFILE Response

    ### Save data
    PVLngPUT $GUID @$RESPONSEFILE

}

##############################################################################
### Init
##############################################################################
. $pwd/../PVLng.sh

### Script options
opt_help      "Read data from Fronius inverters/SensorCards"
opt_help_hint "See dist/fronius.conf for details."

### PVLng default options with flag for save data
opt_define_pvlng x

. $(opt_build)

read_config "$CONFIG"

### Run only during daylight +- 60 min
check_daylight 60

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

check_required APIURL 'Solar Net API URL'

##############################################################################
### Go
##############################################################################
temp_file RESPONSEFILE

curl="$(curl_cmd --header 'Content-Type=application/json')"

for i in $(getGUIDs); do

    sec 1 $i

    ### If not USE is set, set to $i
    var1 USE $i $i
    var1 GUID $USE

    ### Request type and serial, required fields
    PVLngChannelAttr $GUID CHANNEL
    [ "$CHANNEL" ] || log 1 "ERROR: No channel defined for GUID $GUID" && exit
    lkv 2 Channel $CHANNEL

    PVLngChannelAttr $GUID SERIAL
    [ "$SERIAL" ] || log 1 "ERROR: No type (serial) defined for GUID $GUID" && exit
    lkv 2 Type $SERIAL

    CHANNEL=$(int "$CHANNEL")
    [ $CHANNEL -eq 1 ] && requestComCard GetInverterRealtimeData CommonInverterData
    [ $CHANNEL -eq 2 ] && requestComCard GetInverterRealtimeData CommonInverterData
    [ $CHANNEL -eq 2 ] && requestComCard GetStringRealtimeData NowStringControlData
    [ $CHANNEL -eq 3 ] && requestComCard GetSensorRealtimeData NowSensorData

done
