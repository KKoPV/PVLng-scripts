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
opt_help      "Fetch disk usage"
opt_help_args "<config file>"
opt_help_hint "See df.conf.dist for details."

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
DF_FILE=$(temp_file)
on_exit_rm $DF_FILE

df >$DF_FILE

log 2 @$DF_FILE

i=0

while [ $i -lt $GUID_N ]; do

    i=$(($i+1))

    log 1 "--- GUID $i ---"

    var1 GUID $i
    [ "$GUID" ] || error_exit "Channel GUID is required (GUID_$i)"

    var1 MOUNT $i
    df="$(grep -e ${MOUNT}$ $DF_FILE | head -n1)"

    [ "$df" ] || continue

    lkv 1 Found "$(echo $df | sed 's~\t~ ~g')"

    set $df
    value=$(calc "$3 * 100 / $2")
    lkv 1 Value $value

    ### Save data
    [ "$TEST" ] || PVLngPUT $GUID $value

done
