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

### API URL with placeholders
APIURL='http://api.forecast.solar/r1/estimate/watts/0000-0000-0000/$LAT/$LON/$SLOPE/$AZIMUTH/$POWERPEAK'

##############################################################################
### Init
##############################################################################
. $pwd/../PVLng.sh

### Script options
opt_help      "Fetch data from Forecast.Solar API"
opt_help_hint "See dist/string.conf for details."

### PVLng default options
opt_define_pvlng

. $(opt_build)

read_config "$CONFIG"

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

check_required LAT  'Latitude'
check_required LON  'Longitude'
check_required GUID 'Pac estimate channel GUID'

##############################################################################
### Go
##############################################################################
temp_file CSVFILE

eval APIURL="$APIURL"
log 2 Fetch $APIURL

### Query API, get CSV
$(curl_cmd) --header 'Accept: text/csv' --output $CSVFILE $APIURL
rc=$?

[ $rc -eq 0 ] || curl_error_exit $rc "Forecast.Solar API"

log 2 @$CSVFILE "API response"

PVLngPUTCSV $GUID @$CSVFILE
