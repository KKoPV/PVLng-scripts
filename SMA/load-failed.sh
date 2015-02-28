#!/bin/bash
##############################################################################
### @author      Knut Kohl <github@knutkohl.de>
### @copyright   2012-2015 Knut Kohl
### @license     MIT License (MIT) http://opensource.org/licenses/MIT
### @version     1.0.0
##############################################################################

##############################################################################
### Init
##############################################################################
pwd=$(dirname $0)

. $pwd/../PVLng.sh

while getopts "ntvxh" OPTION; do
    case "$OPTION" in
        n) KEEP=y ;;
        t) TEST=y; KEEP=y; VERBOSE=$((VERBOSE + 1)) ;;
        v) VERBOSE=$((VERBOSE + 1)) ;;
        x) TRACE=y ;;
        h) usage; exit ;;
        ?) usage; exit 1 ;;
    esac
done

shift $((OPTIND-1))

read_config "$1"

##############################################################################
### Start
##############################################################################
test "$TRACE" && set -x

GUID_N=$(int "$GUID_N")
test $GUID_N -gt 0 || error_exit "No GUIDs defined (GUID_N)"

curl=$(curl_cmd)
i=0

while test $i -lt $GUID_N; do

    i=$((i + 1))

    var1 GUID $i
    test "$GUID" || error_exit "Equipment GUID is required (GUID_$i)"

    log 0 --- $GUID ---

    find $pwd/../data/fail/$GUID/*/* -type f 2>/dev/null | while read file; do

        log 0 Process $(basename $file) ...

        if test -z "$TEST"; then

            ### Clear temp. file before
            >$TMPFILE

            rc=$($curl --request PUT \
                       --header "X-PVLng-key: $PVLngAPIkey" \
                       --write-out %{http_code} \
                       --output $TMPFILE \
                       --data-binary "@$file" \
                       $PVLngURL/data/$GUID.tsv)

            if echo "$rc" | grep -qe '^20[012]'; then
                ### 200/201/202 Ok
                msg="> Ok [$rc] $(cat $TMPFILE | tail -n 1)"

                if test -z "$KEEP"; then
                    rm "$file" && msg="$msg - deleted"
                    ### Delete both levels (year-month/day) below GUID
                    find $(dirname $file) -type d -empty -delete
                    find $(dirname $(dirname $file)) -type d -empty -delete
                fi

                log 0 "$msg"
            else
                ### Any other is an error
                error_exit "Failed [$rc] $(cat $TMPFILE | tail -n 1)"
            fi
        fi
    done
done

set +x

exit

##############################################################################
# USAGE >>

Load Webbox JSON files via API
Deletes successful imported files and afterwards empty directories!

Usage: $scriptname [options] config_file

Options:

    -n  DON'T delete successful imported file(s)
    -t  Test mode, don't save to PVLng
        Sets verbosity to info level
    -v  Set verbosity level to info level
    -vv Set verbosity level to debug level
    -h  Show this help

# << USAGE
