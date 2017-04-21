#!/bin/bash
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

APIURL=https://api.pushover.net/1/messages.json

. $pwd/../opt.sh

: ${CURL:=$(which curl)}

[ "$CURL" ] || usage 'ERROR: Missing curl binary' 1

### Script options
opt_help      "Send message to pushover.net, refer to https://pushover.net/api for details"
opt_help_hint "Always the system timestamp is used"

opt_define short=u long=user variable=USER desc='User token' required=y
opt_define short=a long=token variable=TOKEN desc='Application token' required=y
opt_define short=d long=device variable=DEVICE desc='Device or group [default:all devices]'
opt_define short=t long=title variable=TITLE desc='Message title [default:application name]'
opt_define short=m long=message variable=MESSAGE desc='Message to send' required=y
opt_define short=p long=priority variable=PRIORITY desc='Message priority, (-2..2)' default=0
opt_define short=r long=url variable=URL desc='Supplementary URL'
opt_define short=l long=url_title variable=URLTITLE desc='Title for supplementary URL'
opt_define short=s long=sound variable=SOUND desc='Name of one of the sounds'

. $(opt_build)

[ "$USER" ]    || usage 'ERROR: Missing user token' 1
[ "$TOKEN" ]   || usage 'ERROR: Missing application token' 2
[ "$MESSAGE" ] || usage 'ERROR: Missing message' 127

$CURL --silent \
      -d user="$USER" -d token="$TOKEN" -d device="$DEVICE" -d title="$TITLE" \
      -d message="$MESSAGE" -d url="$URL" -d url_title="$URLTITLE" \
      -d priority=$PRIORITY -d sound="$SOUND" $APIURL
