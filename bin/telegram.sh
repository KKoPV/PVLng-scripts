#!/usr/bin/env bash
##############################################################################
###  ______     ___                                     _       _
### |  _ \ \   / / |    _ __   __ _       ___  ___ _ __(_)_ __ | |_ ___
### | |_) \ \ / /| |   | '_ \ / _` |_____/ __|/ __| '__| | '_ \| __/ __|
### |  __/ \ V / | |___| | | | (_| |_____\__ \ (__| |  | | |_) | |_\__ \
### |_|     \_/  |_____|_| |_|\__, |     |___/\___|_|  |_| .__/ \__|___/
###                           |___/                      |_|
###
### @author     Knut Kohl <github@knutkohl.de>
### @copyright  2012-2016 Knut Kohl
### @license    MIT License (MIT) http://opensource.org/licenses/MIT
### @version    1.0.0
##############################################################################
pwd=$(dirname $0)

. $pwd/../PVLng.sh

: ${CURL:=$(which curl)}

[ "$CURL" ] || usage 'ERROR: Missing curl binary' 1

### Script options
opt_help      "Send message to telegram bot, refer to https://core.telegram.org/bots/api for details"
opt_help_args '<Message text goes here ...>'

opt_define short=a long=token variable=TOKEN desc='Auth token' required=y
opt_define short=c long=chat variable=CHAT desc='Chat id'
opt_define short=e long=extra variable=EXTRA desc='Extra parameter passed direct to curl'
opt_define short=t long=test variable=TEST desc='Test auth token, just send a getMe' value=y

. $(opt_build)

### Token is always required
[ "$TOKEN" ] || usage 'ERROR: Missing auth token' 2

if [ -z "$TEST" ]; then
    ### If not in test mode, chat id is required
    [ "$CHAT" ]    || usage 'ERROR: Missing chat id' 127
    ### Remaining arguments are the message and empty message ends script
    [ "$ARGS" ] || exit
fi

### Just test token
if [ "$TEST" ]; then
    curl --silent https://api.telegram.org/bot$TOKEN/getMe | \
    php -r 'echo json_encode(json_decode(stream_get_contents(STDIN)), JSON_PRETTY_PRINT);'
    exit
fi

### Is the 3rd given parameter a file name (starting with @)?
if [ ${ARGS:0:1} == @ ]; then
    ### Use file direct as message
    text=${ARGS:1}
else
    text=$(mktemp)
    trap 'rm $text' 0
    echo "$ARGS" >$text
fi

### Send message, returns JSON string
### https://core.telegram.org/bots/api#sendmessage
curl --silent --data chat_id=$CHAT --data-urlencode text@$text $EXTRA https://api.telegram.org/bot$TOKEN/sendMessage
