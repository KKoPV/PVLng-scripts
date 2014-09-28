#!/bin/bash
##############################################################################
### @author      Knut Kohl <github@knutkohl.de>
### @copyright   2014 Knut Kohl
### @license     MIT License (MIT) http://opensource.org/licenses/MIT
### @version     1.0.0
##############################################################################

##############################################################################
### Init
##############################################################################

. $(dirname $0)/../PVLng.sh

### Script options
opt_help      "Read Solar Edge Optimizer data as CSV from portal"
opt_help_args "<config file>"
opt_help_hint "See BoxCSV.conf.dist for details."

### PVLng default options with flag for save data
opt_define_pvlng x

. $(opt_build)

read_config "$1"

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

[ "$SITE" ] || error_exit "Site Id is required (SITE)!"
[ "$USER" ] || error_exit "User name is required (USER)!"

GUID_N=$(int "$GUID_N")
[ $GUID_N -gt 0 ] || error_exit "No GUIDs defined (GUID_N)"

##############################################################################
### Go
##############################################################################
SEUrl=http://monitoring.solaredge.com/solaredge-web/p

JAR_FILE=$(temp_file)
on_exit_rm $JAR_FILE

CSVFILE=$(temp_file)
on_exit_rm $CSVFILE
   
curl="$(curl_cmd)"

### Run only during daylight +- 60 min
#daylight=$(PVLngGET "daylight/60.txt")
#log 2 "Daylight: $daylight"
#[ $daylight -eq 1 ] || exit 127

### Login and remember credetials
$curl --request POST \
      --cookie-jar $JAR_FILE \
      --data cmd=login \
      --data demo=false \
      --data scripts= \
      --data username="$USERNAME" \
      --data password="$PASSWORD" \
      --data remember=on \
      ${SEUrl}/submitLogin
rc=$?

### cUrl error?
[ $rc -eq 0 ] || error_exit "cUrl error for Webbox: $rc"

### Add site id to cookie
echo -e "monitoring.solaredge.com\tFALSE\t/\tFALSE\t0\tSolarEdge_Field_ID\t$SITE" >> $JAR_FILE

### Calculate start and end timestamps
end=$(date +%s)
start=$(calc "$end - 500")

i=0

while [ $i -lt $GUID_N ]; do

    i=$((i+1))

    log 1 "--- $i ---"

    var1 GUID $i
    if [ -z "$GUID" ]; then
        log 1 Disabled, skip
        continue
    fi

    var1 SERIAL $i
    if [ -z "$SERIAL" ]; then
        ### Read from API
        PVLngChannelAttr $GUID SERIAL
    fi
    [ "$SERIAL" ] || error_exit "No Box Id found for GUID_$i: $GUID"

    ### Empty old CSV file
    echo -n > $CSVFILE

    $curl --cookie $JAR_FILE \
          --output $CSVFILE \
          "${SEUrl}/chartExport?st=${start}000&et=${end}000&fid=$SITE&timeUnit=0&pn0=Energy&id0=$SERIAL&t0=0&pn1=Power&id1=$SERIAL&t1=0&pn2=Current&id2=$SERIAL&t2=0&pn3=Voltage&id3=$SERIAL&t3=0&pn4=PowerBox%20Voltage&id4=$SERIAL&t4=0"
    
    if [ -s $TMPFILE ]; then
        log 1 "Response:"
        log 1 @$CSVFILE
        [ "$TEST" ] || PVLngPUTraw $GUID @$TMPFILE
    else
        log 1 "No valid / empty response!"
    fi

done
