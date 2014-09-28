#!/bin/bash
##############################################################################
### @author      Knut Kohl <github@knutkohl.de>
### @copyright   2012-2013 Knut Kohl
### @license     GNU General Public License http://www.gnu.org/licenses/gpl.txt
### @version     $Id$
##############################################################################

##############################################################################
### Init
##############################################################################
pwd=$(dirname $0)

VERBOSE=0

. $pwd/../PVLng.conf
. $pwd/../PVLng.sh

while getopts "tvrxh" OPTION; do
    case "$OPTION" in
        v) VERBOSE=$((VERBOSE+1)) ;;
        x) TRACE=y ;;
        h) usage; exit ;;
        ?) usage; exit 1 ;;
    esac
done

shift $((OPTIND-1))
CONFIG="$1"

read_config "$CONFIG"

##############################################################################
### Start
##############################################################################
test "$GUID" || error_exit "No GUID defined (GUID)"
test "$FORMAT" || ( FORMAT="%s": log 1 "Set FORMAT to '%s'" )


##############################################################################
### Go
##############################################################################
test "$TRACE" && set -x

data=$(PVLngGET "data/$GUID.tsv?period=readlast")

if test "$data"; then
    set $data
    printf "%s;$FORMAT\n" "$(date +'%Y-%m-%d %H:%M;%s')" "$2"
fi

set +x

exit

##############################################################################
# USAGE >>

Get last reading of a single channel.
Can be logged to file for e.g. for solar estimate over day

Usage: $scriptname [options] config_file

Options:

    -v  Set verbosity level to info level
    -vv Set verbosity level to debug level
    -h  Show this help

See watch.conf.dist for details

# << USAGE
