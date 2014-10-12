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
function saveLoadAvg { lkv 1 $@; [ "$1" -a -z "$TEST" ] && PVLngPUT $@; }

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

##############################################################################
### Go
##############################################################################
### Get load and set load to $1, $2, $3
### set $4 to number of currently running processes
### set $5 to the total number of processes
set $(sed -e 's~/~ ~' /proc/loadavg)

[ "$TEST" ] && exit

i=0

function SaveLoadAvg {
    i=$((i+1))
    log 1 "--- $i ---"
    lkv 2 "$1" "$2"
    [ "$1" -a "$2" ] && PVLngPUT $@
}

SaveLoadAvg "$LOADAVG_1"  $1
SaveLoadAvg "$LOADAVG_5"  $2
SaveLoadAvg "$LOADAVG_15" $3
SaveLoadAvg "$RUNNIG"     $4
SaveLoadAvg "$PROCESSES"  $5
