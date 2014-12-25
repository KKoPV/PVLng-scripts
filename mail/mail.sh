#!/bin/sh
##############################################################################
### @author      Knut Kohl <github@knutkohl.de>
### @copyright   2012-2014 Knut Kohl
### @license     MIT License (MIT) http://opensource.org/licenses/MIT
### @version     1.0.0
##############################################################################

##############################################################################
### Init
##############################################################################
pwd=$(dirname $0)

. $pwd/../PVLng.sh

### Script options
opt_help      "Send channel readings by email"
opt_help_args "<config file>"
opt_help_hint "See dist/daily.conf for an example."

### PVLng default options
opt_define_pvlng

. $(opt_build)

read_config "$1"

##############################################################################
### Start
##############################################################################
[ "$EMAIL" ] || error_exit "Email is required! (EMAIL)"
[ "$SUBJECT" ] || error_exit "Subject is required! (SUBJECT)"

GUID_N=$(int "$GUID_N")
[ $GUID_N -gt 0 ] || error_exit "No GUIDs defined (GUID_N)"

##############################################################################
### Go
##############################################################################
[ "$TRACE" ] && set -x

if [ "${BODY:0:1}" == @ ]; then
    BODY="$pwd/${BODY:1}"
    [ -r "$BODY" ] || error_exit "Missing mail template: $BODY"
    BODY=$(<$BODY)
fi

SUBJECT=$(
    echo "$SUBJECT" | \
    sed -e "s~[{]DATE[}]~$(date +%x)~g" -e "s~[{]DATETIME[}]~$(date +'%x %X')~g"
)

BODY=$(
    echo "$BODY" | \
    sed -e "s~[{]DATE[}]~$(date +%x)~g" -e "s~[{]DATETIME[}]~$(date +'%x %X')~g"
)

curl=$(curl_cmd)

i=0

while [ $i -lt $GUID_N ]; do

    i=$((i+1))

    log 1 "--- # $i ---"

    var1 GUID $i
    if [ -z "$GUID" ]; then
        log 1 'Disabled, skip'
        continue
    fi

    PVLngChannelAttr $GUID NAME
    PVLngChannelAttr $GUID DESCRIPTION
    PVLngChannelAttr $GUID UNIT
    PVLngChannelAttr $GUID DECIMALS

    ### Extract 2nd value == data
    value=$(toFixed $(PVLngGET data/$GUID.tsv?period=last | cut -f2) $DECIMALS)

    ### Format for this channel defined?
    var1 FORMAT $i
    if [ "$FORMAT" ]; then
        lkv 2 Format "$FORMAT"
        printf -v value "$FORMAT" "$value"
    fi

    if [ -z "$BODY" ]; then
        [ "$DESCRIPTION" ] && NAME="$NAME ($DESCRIPTION)"
        BODY="$BODY- $NAME: $value $unit\n"
    else
        BODY=$(
            echo "$BODY" | \
            sed -e "s~[{]NAME_$i[}]~$NAME~g" \
                -e "s~[{]DESCRIPTION_$i[}]~$DESCRIPTION~g" \
                -e "s~[{]VALUE_$i[}]~$value~g" \
                -e "s~[{]UNIT_$i[}]~$UNIT~g"
        )
    fi

done

lkv 1 "Send email to" "$EMAIL"
lkv 1 Subject "$SUBJECT"
lkv 1 Body "\n$BODY"

[ "$TEST" ] && exit

echo -e "$BODY" | \
mail -a "From: PVLng@$(hostname --long)" \
     -a "Content-Type: text/plain; charset=UTF-8" \
     -s "$SUBJECT" "$EMAIL" >/dev/null
