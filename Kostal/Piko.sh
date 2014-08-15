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

. $pwd/../PVLng.conf
. $pwd/../PVLng.sh

while getopts "stvxh" OPTION; do
    case "$OPTION" in
        s) SAVEDATA=y ;;
        t) TEST=y; VERBOSE=$((VERBOSE + 1)) ;;
        v) VERBOSE=$((VERBOSE + 1)) ;;
        x) TRACE=y ;;
        h) usage; exit ;;
        ?) usage; exit 1 ;;
    esac
done

shift $((OPTIND-1))

HEADER=6

read_config "$1"

##############################################################################
### Start
##############################################################################
test "$TRACE" && set -x

GUID_N=$(int "$GUID_N")
test $GUID_N -gt 0  || error_exit "No GUIDs defined (GUID_N)"

if test "$LOCATION"; then
    ### Location given, test for daylight time
    loc=$(echo $LOCATION | sed -e 's/,/\//g')
    daylight=$(PVLngGET "daylight/$loc/60.txt")
    log 2 "Daylight: $daylight"
    test $daylight -eq 1 || exit 127
fi

##############################################################################
### Go
##############################################################################
TMPFILE2=$(mktemp /tmp/pvlng.XXXXXX)
on_exit_rm "$TMPFILE2"
CNTFILE=$(mktemp /tmp/pvlng.XXXXXX)
on_exit_rm "$CNTFILE"
RESPONSEFILE=$(mktemp /tmp/pvlng.XXXXXX)
on_exit_rm "$RESPONSEFILE"

curl="$(curl_cmd)"

lines=0
echo 0 >$CNTFILE
i=0

while test $i -lt $GUID_N; do

    i=$((i + 1))

    log 1 "--- $i ---"

    var1 PIKOURL $i
    test "$PIKOURL" || error_exit "Kostal Piko API URL is required (PIKOURL_$i)"

    var1 GUID $i
    test "$GUID" || error_exit "Inverter GUID is required (GUID_$i)"

    ### Fetch data
    $curl --output $TMPFILE $PIKOURL
    rc=$?

    if test $rc -ne 0; then
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

        test "$line" || continue

        lines=$(( $lines + 1 ))
        log 2 "Line: $lines"
        ### Put lines in temp. file from subshell
        echo $lines >$CNTFILE

        ( echo "$names"; echo "$line" ) >$TMPFILE2

        ### Encode data file to JSON for API PUT
        rc=$($curl --request POST --write-out %{http_code} \
                   --output $RESPONSEFILE --data-binary @$TMPFILE2 \
                   $PVLngURL/jsonencode)

        if test $rc -ne 200; then
            echo "RC $rc: JSON encode failed for $TMPFILE"
            cat $TMPFILE
            exit 1
        fi

        ### Save data
        test "$TEST" || PVLngPUT $GUID @$RESPONSEFILE
    done

done

log 1 "Data lines: $(<$CNTFILE)"
log 1 $(run_time x)

set +x

exit

##############################################################################
# USAGE >>

Read data from Kostal Piko inverters

Usage: $scriptname [options] config_file

Options:
    -s  Save data also into log file
    -t  Test mode, read only and show the results, don't save to PVLng
        Sets verbosity to info level
    -v  Set verbosity level to info level
    -vv Set verbosity level to debug level
    -h  Show this help

See $pwd/Piko.conf.dist for reference.

# << USAGE
