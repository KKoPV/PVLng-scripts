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
### Functions
##############################################################################
### $1 - $i
### $2 - GUID
### $3 - Minutes
##############################################################################
function fetch_data {
    if [ "$3" -a $(int "$3") -gt 0 ]; then
        data=$(PVLngGET "data/$2.tsv?start=-${3}minutes&period=last" | awk '{print $2}')
        : ${data:=0}
    else
        data=$(PVLngGET "data/$2.tsv?period=last" | awk '{print $2}')
    fi
    if [ $(numeric "$data") -eq 1 ]; then
        var1 FACTOR $1 1
        data=$(calc "$data * $FACTOR")
    fi

    lkv 2 Data "$data"
    echo "$data"
}

##############################################################################
### $1 - $i
##############################################################################
function render_text {
    var1 TEXT $1
    echo "$TEXT"
}

##############################################################################
### $1 - $i
##############################################################################
function render_data {
    var1 GUID $1
    [ "$GUID" ] || exit_required GUID GUID_$1

    var1 MINUTES $1

    ### Fetch data
    data=$(fetch_data $1 $GUID $MINUTES)

    var1 FORMAT $1 '%s'

    printf "$FORMAT" "$data"
}

##############################################################################
### $1 - $i
##############################################################################
function render_bar {
    var1 GUID $1
    [ "$GUID" ] || exit_required GUID GUID_$1

    var1 MINUTES $1

    ### Fetch data
    data=$(fetch_data $1 $GUID $MINUTES)

    var1 MIN $1 0
    var1 MAX $1 100
    var1 BAR $1 '# '

    local cols=$(calc "$data / ($MAX - $MIN) * $COLUMNS" 0 2)
    lkv 2 Columns $cols

    for ((i=0; i<$cols; i++)); do echo -n ${BAR:0:1}; done
    for ((i=$cols; i<$COLUMNS; i++)); do echo -n ${BAR:1:1}; done
}

##############################################################################
### Init
##############################################################################
. $pwd/../PVLng.sh

### Script options
opt_help      "Create files for LCD display"
opt_help_hint "See dist/LCD.conf for details."

### PVLng default options with flag for local time and save data
opt_define_pvlng

source $(opt_build)

read_config "$CONFIG"

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

: ${FILE:=/tmp/LCD%03d.txt}

LINE_N=$(int "$LINE_N")
[ $LINE_N -gt 0 ] || exit_required Lines LINE_N

##############################################################################
### Go
##############################################################################
i=0

while [ $i -lt $LINE_N ]; do

    i=$(($i+1))

    sec 1 $i

    ### TYPE given?
    var1 TYPE $i
    [ -z "$TYPE" ] && log 1 Skip && continue

    case $TYPE in
        text) data=$(render_text $i) ;;
        data) data=$(render_data $i) ;;
        bar)  data=$(render_bar $i) ;;
        *)    error_exit "Unknown type: $TYPE" ;;
    esac

    file=$(printf "$FILE" $i)
    lkv 1 "$file" "$data"

    [ "$TEST" ] || echo "$data" >$file

done
