#!/bin/bash
##############################################################################
### @author      Knut Kohl <github@knutkohl.de>
### @copyright   2012-2015 Knut Kohl
### @license     MIT License (MIT) http://opensource.org/licenses/MIT
### @version     1.0.0
##############################################################################

##############################################################################
### Constants
##############################################################################
pwd=$(dirname $0)

### Twitter API push URL
APIURL='https://api.twitter.com/1.1/statuses/update.json'

##############################################################################
### Functions
##############################################################################
listItems () {
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
. $pwd/../PVLng.sh
. $pwd/twitter.items.sh

[ -f $pwd/.consumer ] || error_exit "Missing token file! Did you run setup.sh?"

### Script options
opt_help      "Post status to twitter"
opt_help_hint "See dist/twitter.conf for details."

opt_define short=l long=list desc="List implemented items" variable=LIST value=y
### Hidden option to force update also with no valid data
opt_define short=f long=force variable=FORCE value=y

### PVLng default options
opt_define_pvlng

. $(opt_build)

if [ "$LIST" ]; then
    listItems
    exit
fi

read_config "$CONFIG"

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

check_required STATUS 'Status message'

ITEM_N=$(int "$ITEM_N")
[ $ITEM_N -gt 0 ] || exit_required Items ITEM_N

##############################################################################
### Go
##############################################################################
### Used by twitter item functions for buffering
temp_file ITEMTMPFILE

i=0

while [ $i -lt $ITEM_N ]; do

    i=$((i+1))

    sec 1 $i

    ### Check for reused value, skip API call
    var1 USE $i
    if [ "$USE" ]; then
        eval value="\$VALUE_$USE"
    else
        var1 ITEM $i
        var1 GUID $i
        value=$(twitter_$ITEM $GUID)
    fi
    lkv 1 "Item value" "$value"

    ### Remember value
    eval VALUE_$i="\$value"

    ### Exit if no value is found, e.g. no actual power outside daylight times
    [ "$value" ] && [ "$value" != "0" ] || [ "$FORCE" ] || exit

    ### Check if result is numeric
    if [ $(numeric "$value") -eq 1 ]; then
        PVLngChannelAttr $GUID NUMERIC
        if [ $(bool "$NUMERIC") -eq 1 ]; then
            var1 FACTOR $i 1
            ### In case of force set to zero to work properly
            value=$(calc "${value:-0} * $FACTOR")
            lkv 1 Value $value
        fi
    fi

    PARAMS+="$value;"

done

STATUS=$(echo "$STATUS" | sed -e 's/ *|| */\\n/g')

sec 2 Template "$STATUS"
sec 2 Parameter "$PARAMS"

(   ### Sub shell for IFS change
    IFS=';'
    set -- $PARAMS
    printf "$STATUS" $@ >$TMPFILE
)

##############################################################################
log 1 @$TMPFILE Result
lkv 2 Length $(wc -c $TMPFILE)

[ "$TEST" ] && exit

STATUS=$(urlencode "$(<$TMPFILE)")

if [ $VERBOSE -gt 0 ]; then
    opts="-v"
    ### Heavy debug
    set -x
fi

### Put all data into one -d for curlicue
$pwd/contrib/curlicue \
    $opts -f $pwd/.consumer -- \
    -sS -d status="$STATUS&lat=$LAT&long=$LONG" "$APIURL" >$TMPFILE

if grep -q 'errors' $TMPFILE; then
    ### Ignore {"errors":[{"code":187,"message":"Status is a duplicate."}]}
    ### Ignore {"errors":[{"code":186,"message":"Status is over 140 characters."}]}

    ### Extract code from JSON: errors > 0 > code
    code=$($(curl_cmd) --request POST --data-binary @$TMPFILE $PVLngURL/json/errors/0/code.txt)

    if [ $code -ne 186 -a $code -ne 187 ]; then
        msg=$($(curl_cmd) --request POST --data-binary @$TMPFILE $PVLngURL/json/errors/0/message.txt)
        sec -1 'Twitter update error' "[$code] $msg"
    fi
fi

exit $?
