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
opt_help      "Fetch disk usage"
opt_help_args "<config file>"
opt_help_hint "See df.conf.dist for details."

### PVLng default options with flag for local time and save data
opt_define_pvlng x

. $(opt_build)

CONFIG=$1

read_config "$CONFIG"

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

GUID_N=$(int "$GUID_N")
[ $GUID_N -gt 0 ] || exit_required Sections GUID_N

##############################################################################
### Go
##############################################################################
temp_file dffile

df >$dffile
log 2 @$dffile df

i=0

while [ $i -lt $GUID_N ]; do

    i=$(($i+1))

    sec 1 $i

    var1 GUID $i
    [ -z "$GUID" ] && log 1 Skip && continue

    var1 MOUNT $i
    df="$(grep -e ${MOUNT}$ $dffile | head -n1)"

    [ "$df" ] || continue

    lkv 1 Found "$df"

    set -- $df
    value=$(calc "$3 * 100 / $2")
    lkv 1 Value "$value %"

    ### Save data
    [ "$TEST" ] || PVLngPUT $GUID $value

done
