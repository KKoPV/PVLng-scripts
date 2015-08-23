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
MAILFROM="PVLng <PVLng@$HOSTNAME>"

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

GUID_N=$(int "$GUID_N")
[ $GUID_N -gt 0 ] || exit_required Sections GUID_N

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

i=0

while [ $i -lt $GUID_N ]; do

    i=$((i+1))

    sec 1 $i

    var1 GUID $i
    [ -z "$GUID" ] && log 1 Skip && continue

    ### Extract 2nd value == data
    set -- $(PVLngGET data/$GUID.tsv?period=last)
    value=$2
    lkv 1 Value "$value"

    PVLngChannelAttr $GUID NUMERIC

    if [ $(bool "$NUMERIC") -eq 1 ]; then
        var1 FACTOR $i 1
        lkv 1 Factor "$FACTOR"

        value=$(calc "$value * $FACTOR")
        lkv 1 Value "$value"
    fi

    ### Format for this channel defined?
    var1 FORMAT $i
    printf -v value "${FORMAT:-%s}" "$value"

    PVLngChannelAttr $GUID NAME
    PVLngChannelAttr $GUID DESCRIPTION
    PVLngChannelAttr $GUID UNIT

    if [ -z "$BODY" ]; then
        [ "$DESCRIPTION" ] && NAME="$NAME ($DESCRIPTION)"
        BODY="$BODY- $NAME: $value $unit\n"
    else
        BODY=$(
            echo "$BODY" | \
            sed "s~[{]NAME_$i[}]~$NAME~g;s~[{]DESCRIPTION_$i[}]~$DESCRIPTION~g;
                 s~[{]VALUE_$i[}]~$value~g;s~[{]UNIT_$i[}]~$UNIT~g"
        )
    fi

done

sec 1 Send email

lkv 1 "Send email from" "$MAILFROM"
lkv 1 "Send email to" "$EMAIL"
lkv 1 Subject "$SUBJECT"

echo "$BODY" >$TMPFILE
log 1 @$TMPFILE Body

[ "$TEST" ] || mail -a "From: $MAILFROM" -a "Content-Type: text/plain; charset=UTF-8" -s "$SUBJECT" "$EMAIL" <$TMPFILE
