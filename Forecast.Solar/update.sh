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

### API URL
APIURL=https://api.forecast.solar

##############################################################################
### Init
##############################################################################
. $pwd/../PVLng.sh

### Script options
opt_help      "Fetch data from Forecast.Solar API"
opt_help_hint "See dist/update.conf for details."

### PVLng default options
opt_define_pvlng

. $(opt_build)

read_config "$CONFIG"

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

check_required APIURL 'Forecast.Solar API URL'
check_required LAT    'Latitude'
check_required LON    'Longitude'

check_default RESULTSET estimate

if [[ ! $RESULTSET =~ (estimate|history|clearsky) ]]; then
    error_exit "Unknown RESULTSET '$RESULTSET' - must be one of (estimate|history|clearsky)"
fi

if [ "$APIKEY" ]; then
    APIURL="$APIURL/$APIKEY/$RESULTSET/watts/$LAT/$LON"
else
    APIURL="$APIURL/$RESULTSET/watts/$LAT/$LON"
fi

##############################################################################
### Go
##############################################################################
temp_file CSVFILE

curl=$(curl_cmd)

for i in $(getGUIDs); do

    sec 1 $i

    var1 GUID $i
    var1 PLANE $i

    URL="$APIURL/$PLANE"

    log 1 $URL

    ### Query API, get CSV
    $curl --header 'Accept: text/csv' --output $CSVFILE $URL
    rc=$?
    lkv 1 'Curl return' $rc

    [ $rc -eq 0 ] || curl_error_exit $rc "Forecast.Solar API"

    log 2 @$CSVFILE "API response"

    PVLngPUTbulkCSV $GUID @$CSVFILE

done

exit 0
