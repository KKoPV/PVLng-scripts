#!/bin/bash
##############################################################################
### @author      Knut Kohl <github@knutkohl.de>
### @copyright   2012-2013 Knut Kohl
### @license     GNU General Public License http://www.gnu.org/licenses/gpl.txt
### @version     1.0.0
##############################################################################

##############################################################################
### Init
##############################################################################
pwd=$(dirname $0)

. $pwd/PVLng.conf
. $pwd/PVLng.sh

while getopts "c:ntvxh" OPTION; do
    case "$OPTION" in
        c) GUID="$OPTARG" ;;
        n) KEEP=y ;;
        t) TEST=y; KEEP=y; VERBOSE=$((VERBOSE + 1)) ;;
        v) VERBOSE=$((VERBOSE + 1)) ;;
        x) TRACE=y ;;
        h) usage; exit ;;
        ?) usage; exit 1 ;;
    esac
done

shift $((OPTIND-1))

files=$#

if test $files -eq 0; then usage; exit; fi

##############################################################################
### Start
##############################################################################
test "$TRACE" && set -x

i=1

curl=$(curl_cmd)

while test "$1"; do

    log 0 "$(printf "%2d/%2d" $i $files) - $(basename $1) ..."

    i=$((i+1))

    if test -z "$GUID"; then
        ### No channel GUID given, test file name

        ### Ubuntu/Debian don't have the same awk as openSUSE, so the GUID match
        ### didn't work for me. Because of that I changed awk to sed.
        ### https://github.com/K-Ko/PVLng/pull/18
        GUID=$(echo "$1" | sed -n 's/.*\(\([a-z0-9]\{4\}-\)\{7\}[a-z0-9]\{4\}\).*/\1/p')
        test "$GUID" || error_exit "No sensor GUID in filename found"
    fi

    test "$GUID" || error_exit "No sensor GUID given"

    if test -z "$TEST"; then

        ### Clear temp. file before
        >$TMPFILE

        rc=$($curl --request PUT \
                   --header "X-PVLng-key: $PVLngAPIkey" \
                   --header "Content-Type: text/plain" \
                   --write-out %{http_code} \
                   --output $TMPFILE \
                   --data-binary "@$1" \
                   $PVLngURL/csv/$GUID.tsv)

        if echo "$rc" | grep -qe '^20[012]'; then
            ### 200/201/202 Ok
            log 0 "        Ok [$rc] $(cat $TMPFILE | tail -n 1)"

            if test -z "$KEEP"; then
                rm "$1" && log 0 "        deleted"
                if echo $1 | grep -q 'data/fail'; then
                    find $(dirname $1) -empty -type d -delete
                fi
            fi
        else
            ### Any other is an error
            error_exit "Failed [$rc] $(cat $TMPFILE | tail -n 1)"
        fi
    fi

    shift
done

set +x

exit

##############################################################################
# USAGE >>

Load CSV data files via API, delete successful imported files and
if full file name contains 'data/fail' also empty directories!

Usage: $scriptname [-c GUID] [options] files

Options:

    -c  Channel GUID
    -n  DON'T delete successful imported file(s)
    -t  Test mode, don't save to PVLng
        Sets verbosity to info level
    -v  Set verbosity level to info level
    -vv Set verbosity level to debug level
    -h  Show this help

If no GUID is given, it will be extracted from file name.

- Load any failed (/GUID/year/month/*.csv):
    $scriptname data/fail/*/*/*/*.csv

- Load failed january of one GUID and DON'T delete files:
    $scriptname -n data/fail/{GUID}/2014/01/*.csv

- Load failed 1st of january of one GUID:
    $scriptname data/fail/{GUID}/2014/01/*01-01.csv

- Load any file with given GUID:
    $scriptname -c {GUID} file1.csv file2.csv file3.csv

Accepted file format, Semicolon separated lines of:

    <timestamp>;<value>   : timestamp and value
    <date time>;<value>   : date time and value
    <date>;<time>;<value> : date, time and value

# << USAGE
