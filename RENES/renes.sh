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
### http://www.intelligence.tuc.gr/renes/fixed/fixed/api.html
APIURL='http://147.27.14.3:11884/solarAPI/$LAT/$LON/0/$SLOPE/$AZIMUTH/20/1012/19/$POWERPEAK/-0.5/Low/no/0/0/SlopedRoof/90'

##############################################################################
### Init
##############################################################################
. $pwd/../PVLng.sh

### Script options
opt_help      "Fetch data from RENES API"
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
temp_file XMLFILE
temp_file JSONFILE
temp_file CSVFILE

eval APIURL="$APIURL"
log 2 Fetch $APIURL

### Query RENES API
$(curl_cmd) --output $XMLFILE $APIURL
rc=$?

[ $rc -eq 0 ] || curl_error_exit $rc "RENES API"

log 2 @$XMLFILE "XML API response"

xml2json $XMLFILE > $JSONFILE

log 3 @$JSONFILE "JSON data"

i=0

while true; do

    ### Extract timestamp
    timestamp=$(jq @$JSONFILE "tuple[$i]->UTC_epoch")

    [ -z "$timestamp" ] && break ### No data anymore for index $i

    ### Extract estimate power, strip decimals
    watts=$(calc $(jq @$JSONFILE "tuple[$i]->PV_power_output") 0)

    lkv 2 "$(date --date=@$timestamp +'%Y-%m-%d %X')" $watts

    ### Put into CSV file
    echo "$timestamp;$watts" >>$CSVFILE

    i=$((i+1))

done

PVLngPUTCSV $GUID @$CSVFILE
