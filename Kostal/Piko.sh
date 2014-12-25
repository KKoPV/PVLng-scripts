#!/bin/bash
##############################################################################
### @author      Knut Kohl <github@knutkohl.de>
### @copyright   2012-2013 Knut Kohl
### @license     GNU General Public License http://www.gnu.org/licenses/gpl.txt
### @version     1.0.0
##############################################################################

##############################################################################
### Init variables
##############################################################################
pwd=$(dirname $0)

source $pwd/../PVLng.sh

### Script options
opt_help      "Read data from Kostal Piko inverters"
opt_help_args "<config file>"
opt_help_hint "See dist/Piko.conf for details."

### PVLng default options with flag for save data
opt_define_pvlng x

source $(opt_build)

HEADER=6

read_config "$1"

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

GUID_N=$(int "$GUID_N")
[ $GUID_N -gt 0 ] || error_exit "No GUIDs defined (GUID_N)"

[ $(PVLngGET "daylight/60.txt") -eq 1 ] || exit 127

##############################################################################
### Go
##############################################################################
TMPFILE2=$(temp_file)
CNTFILE=$(temp_file)
RESPONSEFILE=$(temp_file)

curl="$(curl_cmd)"

lines=0
echo 0 >$CNTFILE
i=0

while test $i -lt $GUID_N; do

    i=$((i+1))

    log 1 "--- $i ---"

    var1 PIKOURL $i
    [ "$PIKOURL" ] || error_exit "Kostal Piko API URL is required (PIKOURL_$i)"

    var1 GUID $i
    [ "$GUID" ] || error_exit "Inverter GUID is required (GUID_$i)"

    ### Fetch data
    $curl --output $TMPFILE $PIKOURL
    rc=$?

    if [ $rc -ne 0 ]; then
        curl_error_exit $rc $PIKOURL
    fi

    log 2 "Response:"
    log 2 @$TMPFILE
    log 2 "Rows : "$(wc -l $TMPFILE | cut -d' ' -f1)

    ### Split file to send each single row to avoid server timeouts
    ### Extract channel names line
    names=$(head -n $(( $HEADER + 1)) $TMPFILE | tail -1)

    ### Extract data rows behind header and send each prepended with header row to API
    tail -n +$(( $HEADER + 2)) $TMPFILE | while read line; do

        [ "$line" ] || continue

        lines=$(( $lines + 1 ))
        log 2 "Line: $lines"
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

log 1 "Data lines: $(<$CNTFILE)"
log 1 $(run_time x)
