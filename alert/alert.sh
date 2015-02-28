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
replace_vars () {
    ### Prepare conditions
    local str="$1" ### save for looping
    local i=0
    local value=
    local name=
    local last=

    ### On replacing in Condition, $EMPTY is not set, so it works on real data

    ### max. 10 parameters :-)
    while [ $i -lt 10 ]; do
        i=$((i+1))

        var1 name $i
        var1 last $i
        var1 value $i
        [ -z "$value" ] && value=$EMPTY

        str=$(echo "$str" | sed "s~[{]VALUE_$i[}]~$value~g;s~[{]NAME_$i[}]~$name~g;s~[{]LAST_$i[}]~$last~g")
    done

    ### VALUE, NAME and LAST stands also for *_1
    [ -z "$value_1" ] && value_1=$EMPTY
    echo "$str" | sed "s~[{]VALUE[}]~$value_1~g;s~[{]NAME[}]~$name_1~g;s~[{]LAST[}]~$last_1~g"
}


##############################################################################
### Init
##############################################################################
. $pwd/../PVLng.sh

### Script options
opt_help      "Alert on channels conditions"
opt_help_args "<config file>"
opt_help_hint "See alert.conf.dist for details."

opt_define short=r long=reset desc='Reset run files' variable=RESET value=y

### PVLng default options
opt_define_pvlng

. $(opt_build)

if [ "$RESET" ]; then
    ### Reset run files
    sec 1 Reset
    files=$(ls $(run_file alert $CONFIG '*'))
    log 1 "rm $files"
    rm $files
    exit
fi

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
i=0

while [ $i -lt $GUID_N ]; do

    i=$((i+1))

    sec 1 $i

    j=0
    EMPTY=

    while :; do

        j=$((j+1))

        var2 GUID $i $j
        [ "$GUID" ] || break

        PVLngChannelAttr $GUID name
        PVLngChannelAttr $GUID description

        [ "$description" ] && name="$name ($description)"
        eval name_$j="\$name"

        set -- $(PVLngGET data/$GUID.tsv?period=readlast)
        shift ### Shift out timestamp
        value=$@
        lkv 2 "$name" "$value"

        eval value_$j="\$value"

        lastkey=$(key_name alert $CONFIG $i.$j.last)
        last=$(PVLngStoreGET $lastkey 0)
        eval last_$j="\$last"
        [ "$last" != "$value" ] && PVLngStorePUT $lastkey "$value"

    done

    oncekey=$(key_name alert $CONFIG $i.once)

    ### Prepare condition
    var1 CONDITION $i
    [ "$CONDITION" ] || exit_required Condition CONDITION_$i

    CONDITION=$(replace_vars "$CONDITION")
    lkv 1 Condition "$CONDITION"

    result=$(calc "$CONDITION" 0)

    ### Skip if condition is not true
    if [ $result -eq 0 ]; then
        log 1 "Skip, condition not apply."
        ### Remove flag
        PVLngStorePUT $oncekey
        continue
    fi

    ### Condition was true
    var1bool ONCE $i

    ### Skip if flag file exists, condition was true before && ONCE is set
    if [ $ONCE -eq 1 -a "$(PVLngStoreGET $oncekey)" ]; then
        log 1 "Skip, report condition '$CONDITION' only once"
        continue
    fi

    if [ $ONCE -eq 1 ]; then
        ### Mark condition was true
        PVLngStorePUT $oncekey x
    else
        ### Remove flag
        PVLngStorePUT $oncekey
    fi

    var1 ACTION $i
    : ${ACTION:=log}

    var1 EMPTY $i
    : ${EMPTY:=<empty>}

    lkv 1 Action "$ACTION"

    case "$ACTION" in

        log)
            lkv 1 "PVLng log" "$GUID - $value"

            [ "$TEST" ] || save_log 'Alert' "{NAME}: {VALUE}"
            ;;

        logger)
            var1 MESSAGE $i
            MESSAGE=$(replace_vars "${$MESSAGE:-{NAME\}: {VALUE\}}")

            lkv 1 Logger "$MESSAGE"

            [ "$TEST" ] || logger -t PVLng "$MESSAGE"
            ;;

        mail)
            var1 EMAIL $i
            [ "$EMAIL" ] || error_exit "Email is required! (ACTION_${i}_${j}_EMAIL)"

            var1 SUBJECT $i
            SUBJECT=$(replace_vars "${SUBJECT:-[PVLng] {NAME\}: {VALUE\}}")

            var1 BODY $i
            BODY=$(replace_vars "$BODY")

            lkv 1 "Send email" "$EMAIL"
            lkv 1 Subject "$SUBJECT"
            sec 1 Body "$BODY"

            [ "$TEST" ] || echo -e "$BODY" | mail -s "$SUBJECT" $EMAIL >/dev/null
            ;;

        file)
            var1 DIR $i
            [ "$DIR" ] || exit_required Directory ACTION_${i}_DIR

            var1 TEXT $i
            TEXT=$(replace_vars "${TEXT:-{NAME\}: {VALUE\}}")
            lkv 1 Text "$TEXT"

            eval PREFIX=\$ACTION_${i}_PREFIX
            
            [ "$TEST" ] || echo -n "$TEXT" >$(mktemp --tmpdir="$DIR" ${PREFIX:-alert}.XXXXXX)
            ;;

        twitter)
            ### Like "file" but with fixed file name pattern for twitter-file.sh
            var1 TEXT $i
            TEXT=$(replace_vars "${TEXT:-{NAME\}: {VALUE\}}")
            lkv 1 TEXT "$TEXT"

            [ "$TEST" ] || echo -n "$TEXT" >$(mktemp --tmpdir="$RUNDIR" twitter.alert.XXXXXX)
            ;;

        *)
            ### Prepare command
            ACTION=$(replace_vars "$ACTION")
            ### Execute command
            log 1 "$ACTION"
            [ "$TEST" ] || eval $ACTION
            ;;
    esac

done

