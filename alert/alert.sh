#!/bin/sh
##############################################################################
### @author      Knut Kohl <github@knutkohl.de>
### @copyright   2012-2014 Knut Kohl
### @license     MIT License (MIT) http://opensource.org/licenses/MIT
### @version     1.0.0
##############################################################################

##############################################################################
### Init
##############################################################################
pwd=$(dirname $0)

. $pwd/../PVLng.sh

### Script options
opt_help      "Alert on channels conditions"
opt_help_args "<config file>"
opt_help_hint "See alert.conf.dist for details."

opt_define short=x long=trace variable=RESET value=y

### PVLng default options
opt_define_pvlng

. $(opt_build)

CONFIG="$1"

read_config "$CONFIG"

GUID_N=$(int "$GUID_N")
test $GUID_N -gt 0 || error_exit "No sections defined (GUID_N)"

##############################################################################
### Start
##############################################################################
test "$TRACE" && set -x

### Prepare conditions
function replace_vars {
  local str="$1" ### save for looping
  local i=0
  local value=
  local name=
  local last=

  ### On replacing in Condition, $EMPTY is not set, so it works on real data

  ### max. 100 parameters :-)
  while test $i -lt 100; do
    i=$((i+1))

    eval value="\$value_$i"
    [ -z "$value" ] && value=$EMPTY

    eval name="\$name_$i"
    eval last="\$last_$i"

    str=$(echo "$str" | sed -e "s~[{]VALUE_$i[}]~$value~g" \
                            -e "s~[{]NAME_$i[}]~$name~g" \
                            -e "s~[{]LAST_$i[}]~$last~g")
  done

  ### If only 1 is used, VALUE, NAME and LAST are also allowed
  [ -z "$value_1" ] && value_1=$EMPTY
  str=$(echo "$str" | sed -e "s~[{]VALUE[}]~$value_1~g" \
                          -e "s~[{]NAME[}]~$name_1~g" \
                          -e "s~[{]LAST[}]~$last_1~g")

  echo "$str"
}

### Reset run files
function reset {
  files=$(ls $(run_file alert $CONFIG '*'))
  log 1 "Reset, delete $files ..."
  rm $files
}

if [ "$RESET" ]; then
  reset
  exit
fi

curl=$(curl_cmd)

i=0

while [ $i -lt $GUID_N ]; do

    i=$((i+1))

    EMPTY=

    sec 1 $i

    eval GUID_i_N=\$GUID_${i}_N
    GUID_i_N=$(int "$GUID_i_N")

    [ $GUID_i_N -eq 0 ] && continue

    j=0
    numeric=

    while test $j -lt $GUID_i_N; do

        j=$((j+1))

        var2 GUID $i $j

        PVLngChannelAttr $GUID name
        PVLngChannelAttr $GUID description

        [ "$description" ] && name="$name ($description)"
        eval name_$j="\$name"

        data=$(PVLngGET data/$GUID.tsv?period=readlast)
        lkv 2 Data "$data"

        ### Extract 2nd value == data
        value=$(echo "$data" | cut -f2)
        lkv 2 Result "$name - $value"

        ### Test for numerics
        case $value in (*[0-9.]*) numeric=y;; esac

        eval value_$j="\$value"

        lastfile=$(run_file alert $CONFIG "$i.$j.last")
        [ -f $lastfile ] && last=$(<$lastfile) || last=
        eval last_$j="\$last"

        echo -n "$value" >$lastfile

    done

    flagfile=$(run_file alert $CONFIG "$i.once")

    ### Prepare condition
    eval CONDITION=\$CONDITION_$i
    [ "$CONDITION" ] || error_exit "Condition is required (CONDITION_$i)"

    CONDITION=$(replace_vars "$CONDITION")
    lkv 1 Condition "$CONDITION"

    echo "$CONDITION" | grep -qe "[<>]"

    if [ $? -eq 0 ]; then
        ### Numeric condition
        result=$(calc "$CONDITION")
    else
        ### String condition
        eval [ $CONDITION ]
        result=$?
    fi

    ### Skip if condition is not true
    if [ $result != 0 ]; then
        log 1 "Skip, condition not apply."
        ### remove flag file
        rm $flagfile >/dev/null 2>&1
        continue
    fi

    ### Condition was true

    var1 ONCE $i
    ONCE=$(bool "$ONCE")

    ### Skip if flag file exists, condition was true before && ONCE is set
    if [ $ONCE -eq 1 -a -f $flagfile ]; then
        log 1 "Skip, report condition '$CONDITION' only once"
        continue
    fi

    if [ $ONCE -eq 1 ]; then
        ### Mark condition was true
        touch $flagfile
    else
        ### remove flag file
        rm $flagfile >/dev/null 2>&1
    fi

    ### Get actions count
    eval ACTION_N=\$ACTION_${i}_N
    ACTION_N=$(int $ACTION_N)

    j=0

    while [ $j -lt $ACTION_N ]; do

        j=$((j+1))

        sec 1 "Action $j"

        var2 ACTION $i $j

        eval EMPTY=\$ACTION_${i}_${j}_EMPTY
        [ "$EMPTY" ] || EMPTY="<empty>"

        case ${ACTION:-log} in

            log)
                log 1 "Save data to PVLng log"
                lkv 1 Log "$GUID - $value"

                [ "$TEST" ] || save_log 'Alert' "{NAME}: {VALUE}"
                ;;

            logger)
                log 1 "Save data to syslog"
                eval MESSAGE=\$ACTION_${i}_${j}_MESSAGE
                test "$MESSAGE" || MESSAGE="{NAME}: {VALUE}"
                MESSAGE=$(replace_vars "$MESSAGE")

                lkv 1 Logger "$MESSAGE"

                [ "$TEST" ] || logger -t PVLng "$MESSAGE"
                ;;

            mail)
                log 1 "Send email"
                eval EMAIL=\$ACTION_${i}_${j}_EMAIL
                [ "$EMAIL" ] || error_exit "Email is required! (ACTION_${i}_${j}_EMAIL)"

                eval SUBJECT=\$ACTION_${i}_${j}_SUBJECT
                [ "$SUBJECT" ] || SUBJECT="[PVLng] {NAME}: {VALUE}"
                SUBJECT=$(replace_vars "$SUBJECT")

                eval BODY=\$ACTION_${i}_${j}_BODY
                BODY=$(replace_vars "$BODY")

                lkv 1 "Send email" "$EMAIL"
                lkv 1 Subject "$SUBJECT"
                log 1 "Body:"
                log 1 "$BODY"

                [ "$TEST" ] || echo -e "$BODY" | mail -s "$SUBJECT" $EMAIL >/dev/null
                ;;

            file)
                log 1 "Save data to file"
                eval DIR=\$ACTION_${i}_${j}_DIR
                [ "$DIR" ] || error_exit "Directory is required! (ACTION_${i}_${j}_DIR)"

                eval PREFIX=\$ACTION_${i}_${j}_PREFIX
                [ "$PREFIX" ] || PREFIX="alert"

                eval TEXT=\$ACTION_${i}_${j}_TEXT
                [ "$TEXT" ] || TEXT="{NAME}: {VALUE}"
                TEXT=$(replace_vars "$TEXT")

                file=$(mktemp $DIR/$PREFIX.$(date +"%F.%X").XXXXXX)

                lkv 1 Text "$TEXT"
                lkv 1 File "$file"

                [ "$TEST" ] || echo "$TEXT" >$file
                ;;

            *)
                log 1 "Custom command"
                ### Prepare command
                ACTION=$(replace_vars "$ACTION")
                ### Execute command
                log 1 "$ACTION"
                [ "$TEST" ] || eval "$ACTION"
                ;;
        esac

    done

done

[ "$TEST" ] && reset
