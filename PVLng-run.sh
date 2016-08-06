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

. $pwd/PVLng.sh

### Script options
opt_help "Run command each given period (in seconds) for 1 minute.
Use in cron with period * for each minute."
opt_help_args "-- command parameter1 parameter2 ..."

### PVLng default options with flag for save data
opt_define short=p long=period desc="Period in seconds (5..60)" variable=PERIOD default=60
opt_define short=n long=nice desc="Niceness range from -20 (most favorable) to 19 (least favorable)" variable=NICE default=10
opt_define_pvlng

. $(opt_build)

CMD="$@"

##############################################################################
### Start
##############################################################################
if [ "${PERIOD: -1}" == x ]; then
    LOOPS=$(int ${PERIOD::-1})
    PERIOD=$((60 / $LOOPS))
else
    LOOPS=$((60 / $(int $PERIOD)))
fi
[ $PERIOD -gt  0 ] || error_exit "Unknown period"
[ $PERIOD -lt  5 ] && error_exit "Valid period values: 5..60"
[ $PERIOD -gt 60 ] && error_exit "Valid period values: 5..60"

NICE=$(int $NICE)
[ $NICE -lt -20 ] && error_exit "Valid nice level: -20..19"
[ $NICE -gt  19 ] && error_exit "Valid nice level: -20..19"

test "$CMD" || error_exit "No command defined!"

##############################################################################
### Go
##############################################################################
[ "$TRACE" ] && set -x

LOOPS=$((60 / $(int $PERIOD)))

lkv 1 Period "${PERIOD}s"
lkv 1 Calls $LOOPS
lkv 1 "Command given" "$CMD"
CMD="nice --adjustment=$NICE $CMD &"
lkv 1 "Command to run" "$CMD"

while :; do
    if [ "$TEST" ]; then
        log 1 Test ...
    else
        log 1 Run now
        eval $CMD
    fi
    LOOPS=$(($LOOPS - 1))

    ### Break loop if no more left
    if [ $LOOPS -eq 0 ]; then
        log 1 Finished
        exit
    fi

    lkv 1 "Loop(s) left" $LOOPS
    ### Wait ...
    sleep $PERIOD
done
