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

### Header lines to skip
HEADER=6

##############################################################################
### Init
##############################################################################
. $pwd/../PVLng.sh

### Script options
opt_help      "Read data from Kostal Piko inverters"
opt_help_args "<config file>"
opt_help_hint "See dist/Piko.conf for details."

### PVLng default options with flag for save data
opt_define_pvlng x

. $(opt_build)

CONFIG=$1

read_config "$CONFIG"

### Run only during daylight +- 60 min, except in test mode
[ "$TEST" ] || check_daylight 60

read_config "$1"

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

GUID_N=$(int "$GUID_N")
[ $GUID_N -gt 0 ] || exit_required Sections GUID_N

##############################################################################
### Go
##############################################################################
temp_file TMPFILE2
temp_file CNTFILE
temp_file RESPONSEFILE

curl="$(curl_cmd)"

lines=0
echo 0 >$CNTFILE
i=0

while [ $i -lt $GUID_N ]; do

    i=$((i+1))

    sec 1 $i

    var1 PIKOURL $i
    [ "$PIKOURL" ] || exit_required "Kostal Piko API URL" PIKOURL_$i

    var1 GUID $i
    [ -z "$GUID" ] && log 1 Skip && continue

    ### Fetch data
    $curl --output $TMPFILE $PIKOURL
    rc=$?

    [ $rc -eq 0 ] || curl_error_exit $rc $PIKOURL

    log 2 @$TMPFILE Response
    lkv 2 Rows $(wc -l $TMPFILE | cut -d' ' -f1)

    ### Split file to send each single row to avoid server timeouts
    ### Extract channel names line
    names=$(head -n $(($HEADER+1)) $TMPFILE | tail -1)

    ### Extract data rows behind header and send each prepended with header row to API
    tail -n +$(($HEADER+2)) $TMPFILE | \
    while read line; do

        [ "$line" ] || continue

        lines=$(($lines+1))
        lkv 2 Line $lines

        ### Put lines in temp. file from subshell
        echo $lines >$CNTFILE

        ( echo "$names"; echo "$line" ) >$TMPFILE2

        ### Encode data file to JSON for API PUT
        rc=$($curl --request POST --write-out %{http_code} \
                   --output $RESPONSEFILE --data-binary @$TMPFILE2 \
                   $PVLngURL/jsonencode)

        if [ $rc -ne 200 ]; then
            echo "RC $rc: JSON encode failed for $TMPFILE"
            cat $TMPFILE
            exit 1
        fi

        ### Save data
        [ "$TEST" ] || PVLngPUT $GUID @$RESPONSEFILE
    done

done

lkv 1 "Data lines" $(<$CNTFILE)
