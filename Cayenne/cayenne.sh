#!/bin/bash
##############################################################################
### Rewrite from Python to bash from
### https://github.com/myDevicesIoT/Cayenne-MQTT-Python/blob/master/cayenne/client.py
###
### @author      Knut Kohl <github@knutkohl.de>
### @copyright   2012-2015 Knut Kohl
### @license     MIT License (MIT) http://opensource.org/licenses/MIT
##############################################################################

##############################################################################
### Functions
### $1 - Topic, part after client id
### $2 - Message
##############################################################################
function sendMqttData () {
    local topic=v1/$USERNAME/things/$CLIENTID/$1
    local msg=$2
    echo $topic
    echo $msg
    mosquitto_pub -d -q 1 -i $CLIENTID -h $HOST -p $PORT \
                  -u $USERNAME -P $PASSWORD -t $topic -m "$msg"
}

##############################################################################
### Constants
##############################################################################
pwd=$(dirname $0)

### Defaults for Cayenne API
HOST=mqtt.mydevices.com

##############################################################################
### Init
##############################################################################
. $pwd/../PVLng.sh

### Script options
opt_help      "Update channels on Cayenne"
opt_help_hint "See dist/cayenne.conf for details."

### PVLng default options
opt_define_pvlng
opt_define_force ### Used by check_daylight

. $(opt_build)

. $pwd/const.sh

read_config "$CONFIG"

check_daylight 15

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

check_required HOST 'Cayenne MQTT server'
: ${PORT:=1883} ### Default port

check_required USERNAME 'Cayenne MQTT user name'
check_required PASSWORD 'Cayenne MQTT password'
check_required CLIENTID 'Cayenne MQTT client id'

##############################################################################
### Go
##############################################################################
temp_file _RESPONSE

lkv 1 Broker "$HOST:$PORT"

sendMqttData sys/model Bash &>/dev/null
sendMqttData sys/version 1.0.0 &>/dev/null

for i in $(getGUIDs); do

    >$_RESPONSE

    sec 1 $i

    var1 GUID $i
    var1 FACTOR $i
    var1 TYPE $i
    var1 UNIT $i
    var1 START $i
    var1 EMPTY $i
    var1 CHANNEL $i ### NOT documented

    if [ "$START" ]; then
        START='&start='$(urlencode "$START")
    fi

    set -- $(PVLngGET "data/$GUID.tsv?period=last$START")
    value=${2:-$EMPTY}

    ### Silently skip empty data
    [ "$value" ] || continue

    lkv 2 Value "$value"

    [ "$FACTOR" ] && value=$(calc "$value * $FACTOR")

    if [ -z "$CHANNEL" ]; then
        ### Build channel name by default from name  + description
        PVLngChannelAttr $GUID NAME
        PVLngChannelAttr $GUID DESCRIPTION
        CHANNEL="$NAME $DESCRIPTION"
    fi

    ### Reformat if a data type was given
    [ "$TYPE" -a "$UNIT" ] && value="$TYPE,$UNIT=$value"

    lkv 1 Send "$value"

    [ "$TEST" ] && continue

    sendMqttData data/$(slugify "$CHANNEL" _) "$value" &>>$_RESPONSE

    rc=$?
    # -4: MQTT_CONNECTION_TIMEOUT - the server didn't respond within the keepalive time
    # -3: MQTT_CONNECTION_LOST - the network connection was broken
    # -2: MQTT_CONNECT_FAILED - the network connection failed
    # -1: MQTT_DISCONNECTED - the client is disconnected cleanly
    #  0: MQTT_CONNECTED - the cient is connected
    #  1: MQTT_CONNECT_BAD_PROTOCOL - the server doesn't support the requested version of MQTT
    #  2: MQTT_CONNECT_BAD_CLIENT_ID - the server rejected the client identifier
    #  3: MQTT_CONNECT_UNAVAILABLE - the server was unable to accept the connection
    #  4: MQTT_CONNECT_BAD_CREDENTIALS - the username/password were rejected
    #  5: MQTT_CONNECT_UNAUTHORIZED - the client was not authorized to connect

    if [ $rc -eq 0 ]; then
        log 2 @$_RESPONSE
    else
        log 0 "PUB $topic"
        log 0 "$value - FAILED"
        log 0 @$_RESPONSE
    fi

done
