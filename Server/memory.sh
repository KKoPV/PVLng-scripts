#!/bin/bash
##############################################################################
### @author      Knut Kohl <github@knutkohl.de>
### @copyright   2012-2014 Knut Kohl
### @license     MIT License (MIT) http://opensource.org/licenses/MIT
### @version     1.0.0
##############################################################################

##############################################################################
### Init
##############################################################################
source $(dirname $0)/../PVLng.sh

### Script options
opt_help      "Fetch memory usage"
opt_help_args "<config file>"
opt_help_hint "See memory.conf.dist for details."

### PVLng default options with flag for local time and save data
opt_define_pvlng x

source $(opt_build)

read_config "$1"

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

GUID_N=$(int "$GUID_N")
[ $GUID_N -gt 0 ] || error_exit "No sections defined (GUID_N)"

##############################################################################
### Go
##############################################################################
MEM_FILE=$(temp_file)
on_exit_rm $MEM_FILE

cat /proc/meminfo >$MEM_FILE

log 2 @$MEM_FILE

i=0

while [ $i -lt $GUID_N ]; do

    i=$(($i+1))

    log 1 "--- GUID $i ---"

    var1 GUID $i
    [ "$GUID" ] || error_exit "Channel GUID is required (GUID_$i)"

    var1 KEY $i
    mem="$(sed -e 's/[: ]\+/\t/g' $MEM_FILE | grep $KEY)"

    [ "$mem" ] || continue

    lkv 1 Found "$(echo $mem | sed 's~\t~ ~g')"

    set $mem
    lkv 1 Value $2

    ### Save data
    [ "$TEST" ] || PVLngPUT $GUID $2

done
