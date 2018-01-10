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

##############################################################################
### Functions
##############################################################################
listItems () {
    printf '\nImplemented items:\n\n'
    typeset -F | grep ' twitter_' | sed -e 's/.*twitter_//'| \
    while read line; do
        eval help="\$twitter_${line}_help"
        printf '    - %-30s - %s\n' "$line" "$help"
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

check_required USER   'Twitter account'
check_required PASS   'Twittter password'
check_required STATUS 'Status message'

##############################################################################
### Go
##############################################################################
### Used by twitter item functions for buffering
temp_file ITEMTMPFILE
# on_exit "rm -f $ITEMTMPFILE &>/dev/null"

for i in $(getGUIDs); do

    sec 1 $i

    ### If not USE is set, set to $i
    var1 USE $i $i

    ### Check for reused value, skip API call
    if [ $USE -ne $i ]; then
        eval value="\$VALUE_$USE"
    else
        var1 GUID $i
        var1 ITEM $i
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

sec 2 Template  "$STATUS"
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

$BINDIR/tweet.sh "$USER" "$PASS" "$(<$TMPFILE)" >$TMPFILE

rc=$?

[ $rc -eq 0 ] || error_exit "$(<$TMPFILE)"

log 2 @$TMPFILE

exit $rc
