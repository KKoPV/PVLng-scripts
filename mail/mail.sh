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

HOSTNAME=$(hostname -f)

##############################################################################
### Functions
##############################################################################
replaceBaseVars () {
    echo "$1" | sed "s~[{]DATE[}]~$(date +%x)~g;
                     s~[{]DATETIME[}]~$(date +'%x %X')~g;
                     s~[{]HOSTNAME[}]~$HOSTNAME~g"
}

##############################################################################
### Init
##############################################################################
. $pwd/../PVLng.sh

### Script options
opt_help      "Send channel readings by email"
opt_help_hint "See dist/daily.conf for an example."

### PVLng default options
opt_define_pvlng

. $(opt_build)

read_config "$CONFIG"

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

check_required EMAIL Email
check_required SUBJECT Subject

##############################################################################
### Go
##############################################################################
if [ "${BODY:0:1}" == @ ]; then
    BODY="$pwd/${BODY:1}"
    [ -r "$BODY" ] || error_exit "Missing mail template: $BODY"
    BODY=$(<$BODY)
fi

SUBJECT=$(replaceBaseVars "$SUBJECT")
BODY=$(replaceBaseVars "$BODY")

for i in $(getGUIDs); do

    sec 1 $i

    ### If not USE is set, set to $i
    var1 USE $i $i
    var1 GUID $USE

    ### Extract 2nd value == data
    set -- $(PVLngGET data/$GUID.tsv?period=last)
    value=$2
    lkv 1 Value "$value"

    PVLngChannelAttr $GUID NUMERIC

    if [ $(bool "$NUMERIC") -eq 1 ]; then
        var1 FACTOR $i 1
        value=$(calc "${value:-0} * $FACTOR")
        lkv 1 Value "$value"
    fi

    ### Use original channel value in condition before applying the format
    [ "$CONDITION" ] && CONDITION=$(echo "$CONDITION" | sed "s~[{]VALUE_$i[}]~$value~g")

    ### Format for this channel defined?
    var1 FORMAT $i '%s'
    printf -v value "$FORMAT" "$value"

    PVLngChannelAttr $GUID NAME
    PVLngChannelAttr $GUID DESCRIPTION
    PVLngChannelAttr $GUID UNIT
    [ "$DESCRIPTION" ] && NAME_DESCRIPTION="$NAME ($DESCRIPTION)" || NAME_DESCRIPTION="$NAME"

    if [ -z "$BODY" ]; then
        BODY="$BODY- $NAME_DESCRIPTION: $value $unit\n"
    else
        BODY=$(
            echo "$BODY" | \
            sed "s~[{]NAME_$i[}]~$NAME~g;s~[{]DESCRIPTION_$i[}]~$DESCRIPTION~g;
                 s~[{]NAME_DESCRIPTION_$i[}]~$NAME_DESCRIPTION~g;
                 s~[{]VALUE_$i[}]~$value~g;s~[{]UNIT_$i[}]~$UNIT~g"
        )
    fi

done

### Check condition and send mail

sec 1 ---

if [ "$CONDITION" ]; then
    ### Prepare condition
    lkv 1 'Condition def.' "$CONDITION"
    result=$(calc "$CONDITION" 0)
    lkb 1 'Condition res.' $result
else
    result=1
fi

[ "$result" -eq 1 ] && sendMail "$SUBJECT" "$BODY" "$EMAIL"
