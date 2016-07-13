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
function usage {
    echo
    echo "Usage: $0 number message"
    [ "$2" ] && echo && echo "ERROR: $2 - Please refer for setup to yowsup.md"
    exit ${1:-0}
}

[ "$PVLNG_SCRIPTS_VERBOSE" ] && set -x

# Is yowsup correct installed?
: ${CLI:=$(which yowsup-cli)}
[ -z "$CLI" ] && usage 1 'Missing yowsup-cli binary'

# Config file excists?
conf=$(dirname $0)/yowsup.conf
[ ! -f "$conf" ] && usage 2 "Missing $conf"

# Mobile number and message given?
[ -z "$2" ] && usage

# Send message
$CLI demos -c $conf -E android -s $1 "$2"
