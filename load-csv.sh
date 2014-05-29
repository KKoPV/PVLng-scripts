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

while getopts "c:f:ntxh" OPTION; do
    case "$OPTION" in
        c) GUID="$OPTARG" ;;
        f) FILE="$OPTARG" ;;
        n) KEEP=y ;;
        t) TEST=y; KEEP=y ;;
        x) TRACE=y ;;
        h) usage; exit ;;
        ?) usage; exit 1 ;;
    esac
done

shift $((OPTIND-1))

##############################################################################
### Start
##############################################################################
test "$TRACE" && set -x

FILESFILE=$(temp_file)

trap 'rm -f $TMPFILE $FILESFILE >/dev/null 2>&1' 0

if test -f "$FILE"; then
    cp $FILE $FILESFILE
else
    while test "$1"; do
        echo $1 >>$FILESFILE
        shift
    done
fi

if test $(wc -l $FILESFILE | cut -d' ' -f1) -eq 0; then
    usage;
    exit;
fi

i=1

curl=$(curl_cmd)

while read file; do

    if test ! -f $file; then
        log -1 Missing $file - skip
        continue
    fi

    log 0 Process $(basename $file) ...

    i=$((i+1))

    ### No channel GUID given, test file name
    if test -z "$GUID"; then
        ### Ubuntu/Debian don't have the same awk as openSUSE, so the GUID match
        ### didn't work for me. Because of that I changed awk to sed.
        ### https://github.com/K-Ko/PVLng/pull/18
        GUID=$(echo "$file" | sed -n 's/.*\(\([a-z0-9]\{4\}-\)\{7\}[a-z0-9]\{4\}\).*/\1/p')
        test "$GUID" || error_exit "No sensor GUID in filename found"
    fi

    test "$GUID" || error_exit "No channel GUID given"

    if test -z "$TEST"; then

        ### Clear temp. file before
        >$TMPFILE

        rc=$($curl --request PUT \
                   --header "X-PVLng-key: $PVLngAPIkey" \
                   --header "Content-Type: text/plain" \
                   --write-out %{http_code} \
                   --output $TMPFILE \
                   --data-binary "@$file" \
                   $PVLngURL/csv/$GUID.tsv)

        if echo "$rc" | grep -qe '^20[012]'; then
            ### 200/201/202 Ok
            msg="> Ok [$rc] $(cat $TMPFILE | tail -n 1)"

            if test -z "$KEEP"; then
                rm "$file" && msg="$msg - deleted"
                if echo $file | grep -q 'data/fail'; then
                    ### Delete afterwards empty directories
                    find $(dirname $file) -type d -empty -delete
                fi
            fi

            log 0 "$msg"
        else
            ### Any other is an error
            error_exit "Failed [$rc] $(cat $TMPFILE | tail -n 1)"
        fi
    fi

done <$FILESFILE

set +x

exit

##############################################################################
# USAGE >>

Load CSV data files via API, delete successful imported files and
if full file name contains 'data/fail' also empty directories!

Usage: $scriptname [-c GUID] [options] [-f file | files]

Take files list either from file (-f) or from command line

Options:

    -c       Channel GUID
    -f file  Load files from file, the file names MUST contain the GUIDs
    -n       DON'T delete successful imported file(s)
    -t       Test mode, don't save to PVLng
    -h       Show this help

If no GUID is given, it will be extracted from file name.

- Load any failed (/GUID/year-month/*.csv):
    $scriptname data/fail/*/*/*.csv

- Load failed january of one GUID and DON'T delete files:
    $scriptname -n data/fail/{GUID}/2014-01/*.csv

- Load failed 1st of january of one GUID:
    $scriptname data/fail/{GUID}/2014-01/2014-01-01.csv

- Load any file with given GUID:
    $scriptname -c {GUID} file1.csv file2.csv file3.csv

Accepted file format, Semicolon separated lines of:

    <timestamp>;<value>   : timestamp and value
    <date time>;<value>   : date time and value
    <date>;<time>;<value> : date, time and value

# << USAGE
