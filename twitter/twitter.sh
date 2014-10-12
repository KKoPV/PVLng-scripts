#!/bin/bash
##############################################################################
### @author      Knut Kohl <github@knutkohl.de>
### @copyright   2012-2014 Knut Kohl
### @license     MIT License (MIT) http://opensource.org/licenses/MIT
### @version     1.0.0
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

[ -f $pwd/.tokens ] || error_exit "Missing token file! Did you run setup.sh?"

read_config "$1"

. $pwd/.pvlng
. $pwd/.tokens

##############################################################################
[ "$STATUS" ] || error_exit "Missing status!"

ITEM_N=$(int "$ITEM_N")
[ $ITEM_N -gt 0 ] || error_exit "No items defined"

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

TWITTER_URL="https://api.twitter.com/1/statuses/update.json"

curl="$(curl_cmd)"

i=0

while [ $i -lt $ITEM_N ]; do

    i=$((i+1))

    log 1 "--- $i ---"

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

    ### In case of force set to zero to work properly
    value=${value:-0}

    eval FACTOR=\$FACTOR_$i
    lkv 1 Factor "$FACTOR"

    if [ "$FACTOR" ]; then
        value=$(calc "$value * $FACTOR")
        lkv 1 Value $value
    fi

    PARAMS+="$value "

done

log 1 '--- Status ---'
lkv 1 Status "$STATUS"
lkv 1 Parameter "$PARAMS"

STATUS=$(printf "$STATUS" $PARAMS)

##############################################################################
lkv 1 Result "$STATUS"
lkv 1 Length $(echo $STATUS | wc -c)

[ "$TEST" ] && exit

[ $VERBOSE -gt 0 ] && opts="--debug"

$pwd/twitter.php $opts \
    --consumer_key=$CONSUMER_KEY \
    --consumer_secret=$CONSUMER_SECRET \
    --oauth_token=$OAUTH_TOKEN \
    --oauth_secret=$OAUTH_TOKEN_SECRET \
    --status="$STATUS" --location="$LAT_LON"

exit $?
