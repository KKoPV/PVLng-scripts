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
opt_help      "Fetch memory usage"
opt_help_args "<config file>"
opt_help_hint "See memory.conf.dist for details."

### PVLng default options with flag for local time and save data
opt_define_pvlng x

. $(opt_build)

read_config "$1"

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

GUID_N=$(int "$GUID_N")
[ $GUID_N -gt 0 ] || exit_required Sections GUID_N

##############################################################################
### Go
##############################################################################
temp_file memfile

cat /proc/meminfo >$memfile

log 2 @$memfile /proc/meminfo

i=0

while [ $i -lt $GUID_N ]; do

    i=$(($i+1))

    sec 1 $i

    var1 GUID $i
    [ -z "$GUID" ] && log 1 Skip && continue

    var1 KEY $i
    lkv 1 Key $KEY

    set -- $(grep $KEY $memfile | sed -e 's/[: ]\+/\t/g')
    [ "$1" ] || continue

    lkv 1 Value $2

    ### Save data
    [ "$TEST" ] || PVLngPUT $GUID $2

done
