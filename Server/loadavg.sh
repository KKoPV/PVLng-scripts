#!/bin/bash
##############################################################################
### @author     Knut Kohl <github@knutkohl.de>
### @copyright  2012-2014 Knut Kohl
### @license    MIT License (MIT) http://opensource.org/licenses/MIT
### @version    1.0.0
##############################################################################

##############################################################################
### Init
##############################################################################
. $(dirname $0)/../PVLng.sh

### Script options
opt_help      "Save server load from /proc/loadavg"
opt_help_args "<config file>"
opt_help_hint "See loadavg.conf.dist for details."

### PVLng default options with flag for local time and save data
opt_define_pvlng x

source $(opt_build)

read_config "$1"

##############################################################################
### Functions
##############################################################################
function saveLoadAvg {
    log 1 "$1 : $2"
    ### Save data with local timestamp rounded to full minute
    [ "$1" -a -z "$TEST" ] && PVLngPUT $1 $2
}

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

##############################################################################
### Go
##############################################################################

### Get load and set to $1, $2, $3
set $(</proc/loadavg)

### Process all defined GUIDs
saveLoadAvg "$LOADAVG_1"  $1
saveLoadAvg "$LOADAVG_5"  $2
saveLoadAvg "$LOADAVG_15" $3
