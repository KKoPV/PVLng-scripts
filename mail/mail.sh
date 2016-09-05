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
replaceBaseVars () {
    echo "$1" | sed "s~[{]DATE[}]~$(date +%x)~g;
                     s~[{]DATETIME[}]~$(date +'%x %X')~g;
                     s~[{]WEEK[}]~$(date +%V)~g;
                     s~[{]MONTH[}]~$(date +%m)~g;
                     s~[{]MONTHNAME[}]~$(date +%B)~g;
                     s~[{]YEAR[}]~$(date +%Y)~g;
                     s~[{]HOSTNAME[}]~$HOSTNAME~g
                     s~[{]NAME_$i[}]~$NAME~g;s~[{]DESCRIPTION_$i[}]~$DESCRIPTION~g;
                     s~[{]NAME_DESCRIPTION_$i[}]~$NAME_DESCRIPTION~g;
                     s~[{]VALUE_$i[}]~$value~g;s~[{]UNIT_$i[}]~$UNIT~g"
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

. $pwd/mail.items.sh

##############################################################################
### Go
##############################################################################
if [ "${BODY:0:1}" == @ ]; then
    BODY="$pwd/${BODY:1}"
    [ -r "$BODY" ] || error_exit "Missing mail template: $BODY"
    BODY=$(<$BODY)
fi

for i in $(getGUIDs); do

    sec 1 $i

    ### If not USE is set, set to $i
    var1 USE $i $i

    if [ $USE -ne $i ]; then
        value=${values[$USE]}
    else
        var1 GUID  $i
        var1 ITEM  $i last
        fn_exists "mail_$ITEM" || error_exit "Unkwown item function: $ITEM"
        value=$(mail_$ITEM $GUID)
    fi

    ### Remember value for re-use
    values[$i]=$value

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

    SUBJECT=$(replaceBaseVars "$SUBJECT")

    if [ -z "$BODY" ]; then
        BODY="$BODY- $NAME_DESCRIPTION: $value $unit\n"
    else
        BODY=$(replaceBaseVars "$BODY")
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
