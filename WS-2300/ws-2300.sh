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
### Init
##############################################################################
. $pwd/../PVLng.sh

### Script options
opt_help      "Fetch data from WS-2300 weather station"
opt_help_hint "See dist/ws-2300.conf for details."

### PVLng default options
opt_define_pvlng

. $(opt_build)

check_lock $(basename $CONFIG)

read_config "$CONFIG"

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

check_required DEVICE 'Device where weather station is connected'
check_required GUID   'Wunderground group channel GUID'

##############################################################################
### Go
##############################################################################
: ${PYTHON:=$(which python2)}

### Fetch data
$PYTHON $pwd/bin/read.py -c $CHANNELS -w -d $DEVICE -o $TMPFILE

PVLngPUT $GUID @$TMPFILE
