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
APIURL='http://api.wunderground.com/api/$APIKEY/conditions/lang:$LANGUAGE/q/$LOCATION.json'

##############################################################################
### Init
##############################################################################
. $pwd/../PVLng.sh

### Script options
opt_help      "Fetch data from Wunderground API"
opt_help_hint "See dist/wunderground.conf for details."

### PVLng default options
opt_define_pvlng

. $(opt_build)

read_config "$CONFIG"

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

check_default LANGUAGE EN

check_required APIKEY   'Wunderground API key'
check_required GUID     'Wunderground group channel GUID'

##############################################################################
### Go
##############################################################################

### Get location from PVLng settings
LOCATION="$(PVLngGET settings/core/null/Latitude.txt),$(PVLngGET settings/core/null/Longitude.txt)"

eval APIURL="$APIURL"
log 2 $APIURL

### Query Weather Underground API
$(curl_cmd) --output $TMPFILE $APIURL
rc=$?

[ $rc -eq 0 ] || curl_error_exit $rc "Wunderground API"

### Test mode
log 2 @$TMPFILE "API response"

[ "$TEST" ] || PVLngPUT $GUID @$TMPFILE
