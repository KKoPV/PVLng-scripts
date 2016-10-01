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

opt_define short=p long=period variable=PERIOD default=60 \
           desc="Period in seconds (5..60), define only ONE of -p/-l"
opt_define short=l long=loops variable=LOOPS \
           desc="Loops in one minute, define only ONE of -p/-l"
opt_define short=n long=nice variable=NICE default=10 \
           desc="Niceness range from -20 (most favorable) to 19 (least favorable)"

### PVLng default options
opt_define_pvlng

. $(opt_build)

if [ $# -eq 0 ]; then
    usage
    exit
fi

##############################################################################
### Start
##############################################################################
[ "$LOOPS" ] && PERIOD=  ### Remove default value

[ "$PERIOD" -a "$LOOPS" ] && error_exit 'Define only ONE of -p/-l'

if [ "$PERIOD" ]; then
    PERIOD=$(int $PERIOD)
    [ $PERIOD -lt  5 ] && error_exit "Valid period values: 5..60"
    [ $PERIOD -gt 60 ] && error_exit "Valid period values: 5..60"
    [ $PERIOD -gt  0 ] || error_exit "Unknown period"
    LOOPS=$((60 / $PERIOD))
fi

if [ "$LOOPS" ]; then
    LOOPS=$(int $LOOPS)
    PERIOD=$((60 / $LOOPS))
fi

NICE=$(int $NICE)
[ $NICE -lt -20 ] && NICE=-20
[ $NICE -gt  19 ] && NICE=19

CMD="$@"

##############################################################################
### Go
##############################################################################
[ "$TRACE" ] && set -x

lkv 1 Period "${PERIOD}s"
lkv 1 Loops $LOOPS
lkv 1 "Command given" "$CMD"
CMD="nice --adjustment=$NICE $CMD &"
lkv 2 "Command to run" "$CMD"

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

    lkv 1 "Loops left" $LOOPS

    ### Wait ...
    sleep $PERIOD
done
