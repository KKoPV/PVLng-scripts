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

### API URL, will be evaluated later
APIURL='https://pv-log.com/api/v1/$APIKEY/plant/yield/update/$PLANTKEY'

##############################################################################
### Init
##############################################################################
. $pwd/../PVLng.sh

### Script options
opt_help      "Push plant data to PV-Log API"
opt_help_hint "See dist/pv-log.conf for details."

### Script specific options
opt_define short=d long=date variable=DATE default=today \
           desc='Process data for date, format: YYYY-MM-DD'
opt_define short=p long=pretty variable=PRETTY value=y \
           desc='Fetch channel data JSON pretty printed' \
           callback='PRETTY="pretty=true"'

### PVLng default options
opt_define_pvlng

. $(opt_build)

read_config "$CONFIG"

### Run only during daylight ± 60 min
check_daylight 60

##############################################################################
### Start
##############################################################################
[ "$APIKEY" ]   || exit_required 'API key' APIKEY
[ "$PLANTKEY" ] || exit_required 'Plant key' PLANTKEY
[ "$GUID" ]     || exit_required GUID GUID

##############################################################################
### Go
##############################################################################
[ "$TRACE" ] && set -x

temp_file DATAFILE

### Query channel data
[ $DATE == today ] && DATE=$(date +%Y-%m-%d)

PVLngGET "data/$GUID/$DATE.json?$PRETTY" >$DATAFILE
rc=$?
[ $rc -eq 0 ] || curl_error_exit $rc 'PVLng API'
[ -s $DATAFILE ] || error_exit "Empty response"

### Test mode
log 2 @$DATAFILE "Channel data"

eval APIURL="$APIURL"
lkv 2 APIURL "$APIURL"

[ "$TEST" ] && exit

$(curl_cmd) --output $TMPFILE --data-urlencode json@$DATAFILE $APIURL

log 2 @$TMPFILE "PV-Log API response"

type=$(jq @$TMPFILE 'messages[0]->type')

### 2 = error, 3 = success
if [ "${type:-0}" -eq 3 ]; then
    log 1 $(jq @$TMPFILE 'messages[0]->title')
else
    echo "ERROR PV-Log API"
    cat $TMPFILE
    exit 1
fi
