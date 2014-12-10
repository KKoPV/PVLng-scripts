#!/bin/sh
##############################################################################
### @author      Knut Kohl <github@knutkohl.de>
### @copyright   2012-2014 Knut Kohl
### @license     MIT License (MIT) http://opensource.org/licenses/MIT
### @version     1.0.0
##############################################################################

APIURL='https://api.twitter.com/1.1/statuses/update.json'

##############################################################################

function listItems {
    printf '\nImplemented items:\n\n'
    typeset -F | grep ' twitter_' | sed -e 's/.*twitter_//'| \
    while read line; do
        eval help="\$twitter_${line}_help"
        printf '    - %-25s - %s\n' "$line" "$help"
    done
    printf "\nSee $pwd/twitter.items.sh for more details\n"
}

##############################################################################
### Init
##############################################################################
pwd=$(dirname $0)

. $pwd/../PVLng.sh

[ -f $pwd/.consumer ] || error_exit "Missing token file! Did you run setup.sh?"

### Script options
opt_help      "Post status to twitter"
opt_help_args "<config file>"
opt_help_hint "See twitter.conf.dist for details."

opt_define short=l long=list desc="List implemented items" variable=LIST value=y
### Hidden option to force update also with no valid data
opt_define short=f long=force variable=FORCE value=y

### PVLng default options
opt_define_pvlng

. $(opt_build)

. $pwd/twitter.items.sh

if [ "$LIST" ]; then
    listItems
    exit
fi

read_config "$1"

##############################################################################
[ "$STATUS" ] || error_exit "Missing status!"

ITEM_N=$(int "$ITEM_N")
[ $ITEM_N -gt 0 ] || error_exit "No items defined"

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

i=0

while [ $i -lt $ITEM_N ]; do

    i=$((i+1))

    sec 1 $i

    ### Check for reused value, skip API call
    var1 USE $i
    if [ "$USE" ]; then
        lkv 1 Reuse $USE
        eval value="\$VALUE_$USE"
    else
        var1 ITEM $i
        lkv 1 Item "$ITEM"

        var1 GUID $i
        lkv 1 GUID $GUID

        value=$(twitter_$ITEM $GUID)
    fi
    lkv 1 Value "$value"

    ### Remember value
    eval VALUE_$i="\$value"

    ### Exit if no value is found, e.g. no actual power outside daylight times
    [ "$value" ] && [ "$value" != "0" ] || [ "$FORCE" ] || exit

    PVLngChannelAttr $GUID NUMERIC

    if [ $NUMERIC -eq 1 ]; then
        ### In case of force set to zero to work properly
        value=${value:-0}

        eval FACTOR=\$FACTOR_$i
        lkv 1 Factor "${FACTOR:=1}"

        value=$(calc "$value * ${FACTOR:-1}")
    fi

    lkv 1 Value $value

    PARAMS+="$value;"

done

log 1 '--- Status ---'
lkv 1 Status    "$STATUS"
lkv 1 Parameter "$PARAMS"

IFS=';'
set -- $PARAMS
printf -v STATUS "$STATUS" $@

##############################################################################
lkv 1 Result "$STATUS"
lkv 1 Length $(echo "$STATUS" | wc -c)

[ "$TEST" ] && exit
[ $VERBOSE -gt 0 ] && opts="-v"

STATUS=$(urlencode "$STATUS")

if [ $VERBOSE -gt 0 ]; then
    opts="-v"
    set -x
fi

### Put all data into one -d for curlicue
$pwd/contrib/curlicue -f $pwd/.consumer $opts -- \
    -d status="$STATUS&lat=$LAT&long=$LONG" "$APIURL" >$TMPFILE

set +x

if grep -q 'errors' $TMPFILE; then
    cat $TMPFILE
    echo
fi

exit $?
