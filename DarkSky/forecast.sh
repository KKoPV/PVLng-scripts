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
### Units: ca: same as si, except that windSpeed is in kilometers per hour
APIURL='https://api.darksky.net/forecast/$APIKEY/$LAT,$LON?units=si&lang=$LANGUAGE&exclude=minutely,daily,alerts,flags'

##############################################################################
### Init
##############################################################################
. $pwd/../PVLng.sh

### Script options
opt_help      "Fetch data from Dark Sky API"
opt_help_hint "See dist/forecast.conf for details."

### PVLng default options
opt_define_pvlng

. $(opt_build)

read_config "$CONFIG"

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

check_default LANGUAGE EN

check_required APIURL 'Dark Sky API URL'
check_required APIKEY 'Dark Sky API key'
check_required GUID   'Dark Sky group channel GUID'

##############################################################################
### Go
##############################################################################

### Get location from PVLng settings
LAT=$(PVLngGET settings/core/null/Latitude.txt)
LON=$(PVLngGET settings/core/null/Longitude.txt)

eval APIURL="\""$APIURL"\""

log 2 $APIURL

### Query Dark Sky API
$(curl_cmd) --output $TMPFILE $APIURL
rc=$?

[ $rc -eq 0 ] || curl_error_exit $rc "Dark Sky API"

### Test mode
log 2 @$TMPFILE "API response"

[ "$TEST" ] || PVLngPUT $GUID @$TMPFILE

exit 0
