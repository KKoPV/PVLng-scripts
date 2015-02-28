#!/bin/bash
##############################################################################
### @author      Knut Kohl <github@knutkohl.de>
### @copyright   2012-2015 Knut Kohl
### @license     MIT License (MIT) http://opensource.org/licenses/MIT
### @version     1.0.0
##############################################################################

### http://www.photovoltaikforum.com/-f48/-t10594.html

##############################################################################
### Constants
##############################################################################
pwd=$(dirname $0)

### Default Sunny-Portal email adress
MAILTO=datacenter@sunny-portal.de

##############################################################################
### Init
##############################################################################
. $pwd/../PVLng.sh

### Script options
opt_help "Send data via mail to SMA Sunny Portal"
opt_help_args "<config file>"
opt_help_hint "See dist/mail.conf for details."

### Hidden option to force update also outside daylight time
opt_define short=f long=force variable=FORCE value=y

### PVLng default options
opt_define_pvlng

. $(opt_build)

CONFIG=$1

read_config "$CONFIG"

### Run only during daylight +- 60 min, except in test mode or force flag set
[ "$TEST" ] || [ "$FORCE" ] || check_daylight 60

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

check_required SYSTEM 'PV System Identifier'
check_required EMAIL  'Plant Administrator email address'
check_required GUID   'Channel GUID'
check_required TYPE   'Type'

##############################################################################
### Go
##############################################################################
### Send last reading with last timestamp
set -- $(PVLngGET "data/$GUID.tsv?period=last")

VALUE=$2

### No data, e.g. before inverter start
[ "$2" ] || exit 0

DATE=$(date --date=@$1 +%m/%d/%Y)
TIME=$(date --date=@$1 +%H:%M:00)

lkv 1 Value $VALUE

PVLngChannelAttr $GUID METER x

if [ $(bool "$METER") -eq 1 ]; then
    sec 1 "Meter channel"

    offsetkey=$(key_name Sunny-Mail "$CONFIG" offset)
    lastkey=$(key_name Sunny-Mail "$CONFIG" last)
    
    offset=$(PVLngStoreGET "$offsetkey" 0)
    lkv 1 Offset $offset

    last=$(PVLngStoreGET "$lastkey" 0)
    lkv 1 'Last value' $last

    if [ $(calc "$VALUE < $last" 0) -eq 1 ]; then
        ### Actual reading is lower than last reading -> always on a new day
        ### Adjust and remember offset by last stored value 
        offset=$(calc "$offset + $last")
        lkv 1 'Adjust offset' $offset
        PVLngStorePUT "$offsetkey" $offset
    fi

    ### Remember actual reading value
    PVLngStorePUT "$lastkey" $VALUE
    ### Adjust value by offset
    VALUE=$(calc "$offset + $VALUE")
fi

cat <<EOT >$TMPFILE
SUNNY-MAIL
Version;1.2
Source;MANUAL;$SYSTEM
Date;$DATE
Language;EN
Type;Serialnumber;Channel;Date;DailyValue;$TIME
$TYPE;$DATE;$VALUE
EOT

log 1 @$TMPFILE 'Mail body'

[ "$TEST" ] && exit 0

cat $TMPFILE | mail -a "From: $EMAIL" -s Sunny-Mail $MAILTO
 
exit $?
