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

. $pwd/../PVLng.conf
. $pwd/../PVLng.sh

while getopts "tvxh" OPTION; do
    case "$OPTION" in
        t) TEST=y; VERBOSE=$((VERBOSE + 1)) ;;
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

test "$APIURL" || error_exit "Missing API URL (APIURL)!"
test "$GUID" || error_exit "Missing Wunderground group channel GUID (GUID)!"

##############################################################################
### Go
##############################################################################
RESPONSEFILE=$(mktemp /tmp/pvlng.XXXXXX)

trap 'rm -f $TMPFILE $RESPONSEFILE >/dev/null 2>&1' 0

log 2 "$APIURL"

curl="$(curl_cmd)"

### Query OpenWeatherMap API
$curl --output $RESPONSEFILE $APIURL
rc=$?

log 2 @$RESPONSEFILE

if test $rc -ne 0; then
     error_exit "cUrl error for Wunderground API: $rc"
fi

### Test mode
log 2 "Wunderground API response:"
log 2 @$RESPONSEFILE

test "$TEST" || PVLngPUT $GUID @$RESPONSEFILE

exit

##############################################################################
# USAGE >>

Fetch data from Wunderground API

Usage: $scriptname [options] config_file

Options:
    -t   Test mode, don't post
         Sets verbosity to info level
    -v   Set verbosity level to info level
    -vv  Set verbosity level to debug level
    -h   Show this help

See $pwd/station.conf.dist for details.

# << USAGE
