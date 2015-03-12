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

### Write data each ? minutes
MINUTES=10

##############################################################################
### Init
##############################################################################
. $pwd/../PVLng.sh

### Script options
opt_help "Send data once a day via mail to SMA Sunny Portal\n
DON'T call it more than once a day, this will crash the history!\n
The script will check the actual hour and only run between 23:00 and 23:59 (via cron)
Outside this range it will switch to test mode automatic!"
opt_help_args "<config file>"
opt_help_hint "See dist/mail.conf for details."

### PVLng default options
opt_define_pvlng

### Hidden option to force update before 23:00
opt_define short=f long=force variable=FORCE value=y

. $(opt_build)

CONFIG=$1

read_config "$CONFIG"

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

check_required SYSTEM  'PV System Identifier'
check_required EMAIL   'Plant Administrator email address'
check_required GUID    'Channel GUID'
check_required TYPE    'Type'
check_required SERIAL  'Serial number'
check_required CHANNEL 'Channel name'

if [ ! "$FORCE" -a $(date +%H) -lt 23 ]; then
    sec 0 ---
    log 0 Before 23:00, switch to Test mode!
    sec 0 ---
    TEST=y
    VERBOSE=$((VERBOSE+1))
fi

##############################################################################
### Go
##############################################################################
PVLngGET "data/$GUID.tsv?period=${MINUTES}min" >$TMPFILE

[ -s "$TMPFILE" ] || exit

### Evaluates to (0|1), perfect for ((METER))
PVLngChannelAttrBool $GUID METER x

if ((METER)); then
    sec 1 "Meter channel"
    offsetkey=$(key_name Sunny-Mail "$CONFIG" offset-day)
    offset=$(PVLngStoreGET "$offsetkey" 0)
    lkv 1 "Use offset" $offset
fi

while read line; do
    set -- $line

    TIMES="$TIMES$(date --date=@$1 +%H:%M);"

    ### Apply offset to value
    value=$(calc "${offset:=0} + $2" 2)

    VALUE="${VALUE}${value};"
done <$TMPFILE

### Finalize, get last data line
set -- $(tail -n1 $TMPFILE)

TS=$1
LAST=$2
    
if ((METER)); then
    ### Adjust and remember offset by last stored value
    offset=$(calc "$offset + $LAST" 2)
    lkv 1 'Last value' $LAST
    lkv 1 'Adjust offset' $offset
    PVLngStorePUT "$offsetkey" $offset
fi

DATE=$(date --date=@$TS +%m/%d/%Y)

lkv 2 Times "$TIMES"
lkv 2 Values "$VALUE"

cat <<EOT >$TMPFILE
SUNNY-MAIL
Version;1.2
Source;MANUAL;$SYSTEM
Date;$DATE
Language;EN
Type;Serialnumber;Channel;Date;DailyValue;$TIMES
$TYPE;$SERIAL;$CHANNEL;$DATE;;$VALUE
EOT

log 1 @$TMPFILE 'Mail body'

[ "$TEST" ] && exit 0

cat $TMPFILE | mail -a "From: $EMAIL" -s Sunny-Mail $MAILTO
 
exit $?
