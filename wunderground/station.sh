#!/bin/sh
##############################################################################
### @author      Knut Kohl <github@knutkohl.de>
### @copyright   2012-2014 Knut Kohl
### @license     MIT License (MIT) http://opensource.org/licenses/MIT
### @version     1.0.0
##############################################################################

##############################################################################
### Init
##############################################################################

source $(dirname $0)/../PVLng.sh

### Script options
opt_help      "Fetch data from Wunderground API"
opt_help_args "<config file>"
opt_help_hint "See station.conf.dist for details."

### PVLng default options
opt_define_pvlng

source $(opt_build)

read_config "$1"

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

[ "$APIURL" ] || error_exit "Missing API URL (APIURL)!"
[ "$GUID" ] || error_exit "Missing Wunderground group channel GUID (GUID)!"

##############################################################################
### Go
##############################################################################
RESPONSEFILE=$(temp_file)
on_exit_rm $RESPONSEFILE

log 2 "$APIURL"

curl="$(curl_cmd)"

### Query Weather Underground API
$curl --output $RESPONSEFILE $APIURL
rc=$?

log 2 @$RESPONSEFILE

[ $rc -eq 0 ] || error_exit "cUrl error for Wunderground API: $rc"

### Test mode
log 2 "Wunderground API response:"
log 2 @$RESPONSEFILE

[ "$TEST" ] || PVLngPUT $GUID @$RESPONSEFILE
