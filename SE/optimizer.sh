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

### SE API URL
SEIURL=http://monitoring.solaredge.com/solaredge-web/p

##############################################################################
### Init
##############################################################################
. $pwd/../PVLng.sh

### Script options
opt_help      "Read Solar Edge Optimizer data as CSV from portal"
opt_help_hint "See dist/optimizer.conf for details."

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

[ "$SITE" ] || exit_required "Site Id" SITE
[ "$USER" ] || exit_required "User name" USER

GUID_N=$(int "$GUID_N")
[ $GUID_N -gt 0 ] || error_exit Sections GUID_N

##############################################################################
### Go
##############################################################################
temp_file JARFILE
temp_file CSVFILE

curl="$(curl_cmd)"

### Login and remember credetials
$curl --request POST --cookie-jar $JARFILE --data cmd=login --data demo=false \
      --data scripts= --data username="$USERNAME" --data password="$PASSWORD" \
      --data remember=on $SEIURL/submitLogin
rc=$?

### cUrl error?
[ $rc -eq 0 ] || curl_error_exit $rc "SE login"

### Add site id to cookie
echo -e "monitoring.solaredge.com\tFALSE\t/\tFALSE\t0\tSolarEdge_Field_ID\t$SITE" >> $JARFILE

### Calculate start and end timestamps (milli seconds)
start=$(calc "$(date +%s) - 300")000
end=$(date +%s)000

i=0

while [ $i -lt $GUID_N ]; do

    i=$((i+1))

    sec 1 $i

    var1 GUID $i
    [ -z "$GUID" ] && log 1 Skip && continue

    var1 SERIAL $i
    [ "$SERIAL" ] || PVLngChannelAttr $GUID SERIAL
    [ "$SERIAL" ] || error_exit "No Box Id found for GUID_$i: $GUID"

    ### Empty old CSV file
    echo -n >$CSVFILE

    $curl --cookie $JARFILE --output $CSVFILE \
          "$SEIURL/chartExport?st=$start&et=$end&fid=$SITE&timeUnit=0&pn0=Energy&id0=$SERIAL&t0=0&pn1=Power&id1=$SERIAL&t1=0&pn2=Current&id2=$SERIAL&t2=0&pn3=Voltage&id3=$SERIAL&t3=0&pn4=PowerBox%20Voltage&id4=$SERIAL&t4=0"
    rc=$?

    ### cUrl error?
    [ $rc -eq 0 ] || curl_error_exit $rc "SE fetch data"

    if [ -s $TMPFILE ]; then
        log 1 @$CSVFILE
        PVLngPUTraw $GUID @$TMPFILE
    else
        log 1 "No valid / empty response!"
    fi

done
