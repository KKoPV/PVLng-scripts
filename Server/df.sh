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
opt_help_hint "See dist/df.conf for details."

### PVLng default options with flag for local time and save data
opt_define_pvlng x

. $(opt_build)

read_config "$CONFIG"

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

##############################################################################
### Go
##############################################################################
temp_file dffile

df >$dffile
log 2 @$dffile df

for i in $GUIDs; do

    sec 1 $i

    ### If not USE is set, set to $i
    var1 USE $i $i
    var1 GUID $USE

    var1 MOUNT $i
    df="$(grep -e ${MOUNT}$ $dffile | head -n1)"

    [ "$df" ] || continue

    lkv 1 Found "$df"

    set -- $df
    value=$(calc "$3 * 100 / $2")
    lkv 1 Value "$value %"

    ### Save data
    PVLngPUT $GUID $value

done
