#!/bin/sh
##############################################################################
### @author     Knut Kohl <github@knutkohl.de>
### @copyright  2012-2014 Knut Kohl
### @license    MIT License (MIT) http://opensource.org/licenses/MIT
### @version    1.0.0
##############################################################################

APIURL='https://api.thingspeak.com/channels.json'

##############################################################################
### Init
##############################################################################
pwd=$(dirname "$0")

source $pwd/../PVLng.sh

### Script options
opt_help      "Create ThingSpeak channel from GUIDs file"
opt_help_args "<GUIDs file>"
opt_help_hint "Create a text file with PVLng channel GUIDs (one per line) to put into
the new ThingSpeak channel and run

$ ./createChannel.sh <TextFileName>

This will create
- the ThingSpeak channel
- a draft configuration file 'TextFileName.conf'

Open your channels list in your browser and check the just created channel.
https://thingspeak.com/channels

You have to adjust afterwards in the created configuration file at least the
channels API key."

opt_define short=k long=key variable=APIKEY desc='ThingSpeak User API key' required=y
opt_define short=d long=description variable=ADDDESC desc='Add description to field name' value=y
opt_define short=u long=unit variable=ADDUNIT desc='Add unit to field name' value=y

### PVLng default options
opt_define_pvlng

source $(opt_build)

GUIDS="$1"

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

[ "$APIKEY" ] || error_exit "ThingSpeak User API key is required"
[ "$GUIDS" ]  || error_exit "GUIDs file is required"

##############################################################################
### Go
##############################################################################
[ "$TEST" ] || conf_tmp=$(temp_file)

log 0 Fetch channel attributes...

i=0

while read GUID; do

    i=$((i+1))

    sec 1 $i

    lkv 1 GUID $GUID

    PVLngChannelAttr $GUID name

    if [ "$ADDDESC" ]; then
        PVLngChannelAttr $GUID description
        [ "$description" ] && name="$name ($description)"
    fi

    if [ "$ADDUNIT" ]; then
        PVLngChannelAttr $GUID unit
        [ "$unit" ] && name="$name [$unit]"
    fi
    
    lkv 1 Name "$name"
    data="$data&field$i=$(urlencode "$name")"

    ### Prepare config file
    if [ -z "$TEST" ]; then
        (   echo
            echo "### $name"
            echo "GUID_$i         $GUID"
            echo "#FACTOR_$i      1"
        ) >>$conf_tmp
    fi

done <"$GUIDS"

field_cnt=$i
conf=$(basename "$GUIDS")
    
data="key=$APIKEY&name=$conf$data"

sec 1 Send

lkv 2 Data "$data"

[ "$TEST" ] && exit
    
log 0 Create ThingSpeak channel...

### Send
rc=$($(curl_cmd) --write-out %{http_code} \
                 --output $TMPFILE \
                 --data "$data" $APIURL)

lkv 2 "HTTP code" $rc
lkv 2 "API Response" "$(<$TMPFILE)"

### Check result, ONLY not zero is ok
if [ $rc -eq 200 ]; then
    ### Ok, state added
    log 1 "Ok"

    log 0 Create configuration file $pwd/$conf.conf...

    (   echo '### Write API Key'
        echo 'APIKEY         '$(grep -Po '"api_key": *"\K[^"]+' $TMPFILE)
        echo
        echo '### Count of following fields'
        echo "FIELD_N        $field_cnt"
        echo
        echo '### Channels'
        cat $conf_tmp
    ) >"$pwd/$conf.conf"

else
    ### error
    cat $TMPFILE
fi
