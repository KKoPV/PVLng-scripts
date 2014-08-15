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

. $pwd/PVLng.sh

PERIOD=60
NICE=10

while getopts "p:n:tvxh" OPTION; do
    case "$OPTION" in
        p) P=$OPTARG; PERIOD=$(int $OPTARG) ;;
        n) NICE=$(int $OPTARG) ;;
        t) TEST=y;  VERBOSE=$((VERBOSE+1)) ;;
        v) VERBOSE=$((VERBOSE+1)) ;;
        x) TRACE=y ;;
        h) usage; exit ;;
        ?) usage; exit 1 ;;
    esac
done

shift $((OPTIND-1))
CMD="$@"

##############################################################################
### Start
##############################################################################
test $PERIOD -gt 0 || error_exit "Unknown period: $P"
test $PERIOD -lt 5 && error_exit "Valid period values: 5..60"
test $PERIOD -gt 60 && error_exit "Valid period values: 5..60"
test $NICE -lt -20 && error_exit "Valid nice level: -20..19"
test $NICE -gt 19 && error_exit "Valid nice level: -20..19"
test "$CMD" || error_exit "No command defined!"

##############################################################################
### Go
##############################################################################
test "$TRACE" && set -x

LOOPS=$((60 / $PERIOD))

log 1 "Period        : ${PERIOD}s"
log 1 "Calls         : $LOOPS"
log 1 "Command given : $CMD"
CMD="nice --adjustment=$NICE $CMD &"
log 1 "Command to run: $CMD"

while test $LOOPS -gt 0; do
    if test "$TEST"; then
        log 1 Test ...
    else
        eval $CMD
    fi
    LOOPS=$(($LOOPS - 1))
    ### Break loop if no more left
    test $LOOPS -gt 0 || break;
    log 1 "$LOOPS left ..."
    ### Wait ...
    sleep $PERIOD
done

exit 0

##############################################################################
# USAGE >>

Run command each given period (in seconds) for 1 minute.
Use in cron with period * for each minute.

Usage: $scriptname [options] -- command parameter1 parameter2 ...

Options:
    -p    Period in seconds, valid from 5 to 60; default: 60 (run once)
    -n    Niceness range from -20 (most favorable) to 19 (least favorable)
          default 10
    -t    Test mode
          Sets verbosity to info level
    -v    Set verbosity to info level
    -h    Show this help

# << USAGE
