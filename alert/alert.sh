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
function replace_vars {
    ### Prepare conditions
    local str="$1"
    local count=${2:-1}
    local i=0
    local _v=$VERBOSE

    ### Helper
    local name=
    local description=
    local name_desc=
    local value=
    local unit=
    local last=

    ### Check if the content respresents a file name starting with @
    ### If yes, read content from file
    if [ "${str:0:1}" == @ ]; then
        str="$pwd/${str:1}"
        [ -r "$str" ] || error_exit "Missing template: $str"
        str=$(<$str)
    fi

    ### Disable verbose for the loop
    VERBOSE=0
    
    while [ $i -lt $count ]; do
        i=$((i+1))

        var1 name $i
        var1 description $i
        var1 name_desc $i
        var1 value $i $EMPTY
        var1 unit $i
        var1 last $i

        str=$(echo "$str" | \
              sed "s~[{]NAME_$i[}]~$name~g;s~[{]DESCRIPTION_$i[}]~$description~g;
                   s~[{]NAME_DESCRIPTION_$i[}]~$name_desc~g;
                   s~[{]VALUE_$i[}]~$value~g;s~[{]UNIT_$i[}]~$unit~g;
                   s~[{]LAST_$i[}]~$last~g")
    done

    ### Restore verbose
    VERBOSE=$_v

    ### NAME, DESCRIPTION, NAME_DESCRIPTION, VALUE, UNIT and LAST stands also for *_1
    echo "$str" | \
    sed "s~[{]NAME[}]~$name_1~g;s~[{]DESCRIPTION[}]~$description_1~g;
         s~[{]NAME_DESCRIPTION[}]~$name_desc_1~g;
         s~[{]VALUE[}]~${value_1:-$EMPTY}~g;s~[{]UNIT[}]~$unit_1~g;s~[{]LAST[}]~$last_1~g;
         s~[{]DATE[}]~$(date +%x)~g;s~[{]DATETIME[}]~$(date +'%x %X')~g;
         s~[{]HOSTNAME[}]~$HOSTNAME~g"
}

##############################################################################
### Init
##############################################################################
. $pwd/../PVLng.sh

### Script options
opt_help      "Alert on channels conditions"
opt_help_hint "See dist/alert.conf for details."

### PVLng default options
opt_define_pvlng

opt_define short=l long=list variable=LIST value=y \
           desc='List all available functions'

### Hidden option to force (ignore condition and once flag)
### Works only with and set automatic test mode!
opt_define short=f long=force variable=FORCE value=y

. $(opt_build)

if [ "$LIST" ]; then
    for file in $pwd/action/*.sh; do
        action=$(echo $(basename "$file") | sed 's/\.sh//')
        (   echo '##############################################################################'
            echo "### $action"
            echo '##############################################################################'
            cat $pwd/action/$action.txt
            echo
        ) >>$TMPFILE
    done
    less $TMPFILE
    exit
fi

read_config "$CONFIG"

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

### Force mode sets automatic Test mode
[ "$FORCE" ] && TEST=y && VERBOSE=$((VERBOSE+1))

##############################################################################
### Go
##############################################################################
for i in $(getGUIDs); do

    sec 1 $i

    EMPTY=

    ### If not USE is set, set to $i
    var1 USE $i $i
    var1 GUID $USE

    j=0

    ### Split comma separated GUIDs
    for GUID in $(echo "$GUID" | sed 's/ *, */ /g'); do

        ### Count GUIDs for function replace_vars
        j=$((j+1))

        PVLngChannelAttr $GUID name x
        PVLngChannelAttr $GUID description x
        PVLngChannelAttr $GUID unit x

        var1 PERIOD $i readlast

        set -- $(PVLngGET data/$GUID.tsv?period=$PERIOD)
        shift ### Shift out timestamp
        value=$@

        if [ "$value" ]; then
            var1 FACTOR $i 1
            [ $FACTOR != 1 ] && value=$(calc "$value * $FACTOR")

            var1 FORMAT $i '%s'
            printf -v value $FORMAT $value
        fi

        lkv 2 "$name" "$value"

        lastkey=$(key_name alert $CONFIG $i.$j.last)
        last=$(PVLngStoreGET $lastkey)
        [ "$TEST" -o "$last" == "$value" ] || PVLngStorePUT $lastkey "$value"

        eval name_$j="\$name"
        eval description_$j="\$description"
        eval value_$j="\$value"
        eval unit_$j="\$unit"
        eval last_$j="\$last"

        [ "$description" ] && name="$name ($description)"
        eval name_desc_$j="\$name"

    done

    oncekey=$(key_name alert $CONFIG $i.once)

    ### Prepare condition
    var1 CONDITION $i
    [ "$CONDITION" ] || exit_required Condition CONDITION_$i
    CONDITION=$(replace_vars "$CONDITION" $j)
    lkv 1 Condition "$CONDITION"

    result=$(calc "$CONDITION" 0)

    lkb 1 Condition $result

    ### Test result for integer
    if [ "$result" -ne "$result" 2>/dev/null ]; then
        lkv 0 'Invalid condition' "$CONDITION"
        continue
    fi

    if [ -z "$FORCE" ]; then
        ### Skip if condition is not true
        if [ "$result" -eq 0 ]; then
            ### Remove flag
            [ "$TEST" ] || PVLngStorePUT $oncekey
            continue
        fi

        ### Condition was true
        var1bool ONCE $i

        ### Skip if flag exists, condition was true before && ONCE is set
        if [ -z "$TEST" -a $ONCE -eq 1 -a "$(PVLngStoreGET $oncekey)" ]; then
            log 1 "Skip, report condition '$CONDITION' only once"
            continue
        fi

        if [ $ONCE -eq 1 ]; then
            ### Mark condition was true
            [ "$TEST" ] || PVLngStorePUT $oncekey x
        else
            ### Remove flag
            [ "$TEST" ] || PVLngStorePUT $oncekey
        fi
    fi

    var1 ACTION $i log

    var1 EMPTY $i '<empty>'

    ### Check if action function exists
    if [ -s "$pwd/action/$ACTION.sh" ]; then
        . "$pwd/action/$ACTION.sh"
    else
        log 0 ERROR - Unknown function: $ACTION
    fi

done
