##############################################################################
###  ______     ___                                     _       _
### |  _ \ \   / / |    _ __   __ _       ___  ___ _ __(_)_ __ | |_ ___
### | |_) \ \ / /| |   | '_ \ / _` |_____/ __|/ __| '__| | '_ \| __/ __|
### |  __/ \ V / | |___| | | | (_| |_____\__ \ (__| |  | | |_) | |_\__ \
### |_|     \_/  |_____|_| |_|\__, |     |___/\___|_|  |_| .__/ \__|___/
###                           |___/                      |_|
###
### @author     Knut Kohl <github@knutkohl.de>
### @copyright  2012-2016 Knut Kohl
### @license    MIT License (MIT) http://opensource.org/licenses/MIT
### @version    1.0.0
##############################################################################

REQUEST_TIME=$(date +%s.%N)

##############################################################################
### Show message depending of verbosity level on stderr
### $1 - Show from verbose level upwards
### $2 - Output, "string" or read from "@file"
### $3 - Title for file content, default "Result"
##############################################################################
function log {
    [ $VERBOSE -ge $1 ] || return
    local level=$1
    local time=[$(date +%H:%M:%S.%N | cut -b-11)]

    shift ### Move out level

    {   ### Detect if now $1 is a "@filename"
        if [ "${1:0:1}" == '@' ]; then
            file=${1:1}
            sec $level "${2:-Result}"

            ### At least 1 line break at EOF is needed!
            echo >>$file

            while read l; do
                echo "$time $l"
            done <$file
            sec $level ---
        else
            echo "$time $@"
        fi
    } >&2
}

##############################################################################
### Show "key = value" message depending of verbosity level on stderr
### $1 - Show from verbose level upwards
### $2 - Key
### $3 - Value
##############################################################################
function lkv {
    [ $VERBOSE -ge $1 ] || return
    log $1 "$(printf "%-15s = %s" "$2" "$3")"
}

##############################################################################
### Show "key = yes|no" message depending of verbosity level on stderr
### $1 - Show from verbose level upwards
### $2 - Key
### $3 - Value
##############################################################################
function lkb {
    [ $VERBOSE -ge $1 ] || return
    local value=
    [ $(bool "$3") -eq 1 ] && value=yes || value=no
    lkv $1 "$2" $value
}

##############################################################################
### Show a section header
### $1 - Show from verbose level upwards
### $2 - Header
### $@ - Output
##############################################################################
function sec {
    [ $VERBOSE -ge $1 ] || return
    local level=$1
    shift ### Move out level
    local header=$1
    shift ### Move out header
    log $level "--- $header ---"
    ### Further content?
    if [ "$*" ]; then
        log $level $@
        log $level "--- --- ---"
    fi
}

##############################################################################
### show usage
### requires a section of text enclosed by
### # USAGE >>
### ...
### # << USAGE
##############################################################################
# function usage {
#     s=$(cat "$0" | \
#         awk '{if($0~/^#+ +USAGE +>+/){while(getline>0){if($0~/^#+ *<+ *USAGE/)exit;print $0}}}')
#     eval s="$(echo \""$s"\")"
#     echo "$s" >&2
# }

##############################################################################
### read config file
### $1 - Config file name
##############################################################################
function read_config {
    local file=$1

    if [ -z "$file" ]; then
        echo
        echo ERROR: Configuration file required!
        usage
        exit 1
    fi

    [ -f "$file" ] || file="$(dirname $0)/$file"
    [ -r "$file" ] || error_exit "Configuration file is not readable!" 1

    ### Transform configuration into var="value" format

    if [ $VERBOSE -lt 2 ]; then
        ### eval() direct
        eval $(sed '/^$/d;/^ *#/d;s/  *\(.*\)/="\1"/;s/""/"/g' $file)
    else
        ### Pipe through temp. file for log output
        local cfg=$(temp_file)
        on_exit_rm $cfg
        sed '/^$/d;/^ *#/d;s/  *\(.*\)/="\1"/;s/""/"/g' $file >$cfg
        log 2 @$cfg "$(basename $file)"
        . $cfg
    fi
}

##############################################################################
### Force $1 as boolean
### Any of 1,x,on,yes,true is case-insensitive detected as TRUE
### Return 1 for TRUE, 0 for FALSE
##############################################################################
function bool {
    case ${1,,} in
        1|x|on|y|yes|true) echo 1 ;;
        *)                 echo 0 ;;
    esac
}

##############################################################################
### Force $1 as integer
### Return 0 for invalid/empty parameter $1
##############################################################################
function int {
    local t=
    [ "$1" ] && t=$(expr "$1" \* 1 2>/dev/null)
    [ -z "$t" ] && echo 0 || echo $t
}

##############################################################################
### Make $1 to integer
### $1 - variable name
##############################################################################
function toInt {
    eval local val="\$$1"
    [ "$val" ] && val=$(expr "$val" \* 1 2>/dev/null)
    eval $1=\${val:-0}
}

##############################################################################
### Calculation via awk
### $1 - formula, required
### $2 - decimal places, optional; default 4
### $3 - log level to show term, default 9 (never :-)
##############################################################################
function calc {
    ### Replace all ' in formula with "
    local term=$(echo "${1:-0}" | sed 's/'\''/"/g')
    lkv ${3:-9} CALC "$term"
#    local result=$(awk "BEGIN { printf \"%.${2:-4}f\", ($term) }" 2>/dev/null)
    local result=$(awk "BEGIN { printf \"%.${2:-4}f\", ($term) }")

    [ $(numeric "$result") -eq 1 ] && echo $result || echo 0
}

##############################################################################
### Format numeric value with decimals
### $1 - value, required
### $2 - decimals, optional; default 0
##############################################################################
function toFixed {
    local value=${1:-0}
    local decimals=${2:-0}
    printf "%.${decimals}f" $value
}

##############################################################################
### Test if $1 is a numeric value (e.g. valid timestamp or numeric reading value
### $1 - value, required
##############################################################################
function numeric {
    local value=$1
    ### http://www.linuxquestions.org/questions/programming-9/bash-scripting-check-for-numeric-values-352226/#post3993863
    [ "$value" == "${value//[^0-9\.+-]/}" ] && echo 1 || echo 0
}

##############################################################################
### Build md5 hash of file
### $1 - term to hash, required
##############################################################################
function hash {
    local term=$1
    md5sum "$term" | cut -d' ' -f1
}

##############################################################################
### Check variable for existence and value or set to default
### $1 - Variable name
### $2 - Default value if empty
##############################################################################
function check_default {
    eval local val=\$$1
    [ "$val" ] || lkv 1 $1 "$2 (default)"
    eval : \${$1:=$2}
}

##############################################################################
### Check required variable for existence
### $1 - Variable name
### $2 - Error message
##############################################################################
function check_required {
    eval local val=\$$1
    [ "$val" ] || error_exit "$2 required ($1)!"
}

##############################################################################
### Define variable level 1
### $1 - Variable base name
### $2 - Counter level 1
### $3 - Default value, if not set/empty
### If var exists:     var1 FACTOR 1 1000 > $FACTOR will get value of $FACTOR_1
### If var NOT exists: var1 FACTOR 1 1000 > $FACTOR will get 1000
##############################################################################
function var1 {
    eval local val="\$${1}_${2}"
    [ "$val" ] || val="$3"
    ### Mask embeded '
    eval $1="'$(echo $val | sed -e s/\'/\'\\\\\'\'/g)'"
    lkv 2 $1 "$val"
}

##############################################################################
### Define variable level 2
### $1 - Variable base name
### $2 - Counter level 1
### $3 - Counter level 2
### $4 - Default value, if not set/empty
### example: var2 ACTION 1 1 > $ACTION will get value of $ACTION_1_1
##############################################################################
function var2 {
    eval local val="\$${1}_${2}_${3}"
    [ "$val" ] || val="$4"
    ### Mask embeded '
    eval $1="'$(echo $val | sed -e s/\'/\'\\\\\'\'/g)'"
    lkv 2 $1 "$val"
}

##############################################################################
### Define variable level 1 and make integer
### $1 - Variable base name
### $2 - Counter level 1
### $3 - Default value, if not set/empty
##############################################################################
function var1int {
    eval local val="\$${1}_${2}"
    [ "$val" ] || val="$3"
    eval $1=$(int "$val")
    lkv 2 $1 "$val"
}

##############################################################################
### Define variable level 2 and make integer
### $1 - Variable base name
### $2 - Counter level 1
### $3 - Counter level 2
### $4 - Default value, if not set/empty
##############################################################################
function var2int {
    eval local val="\$${1}_${2}_${3}"
    [ "$val" ] || val="$4"
    eval $1=$(int "$val")
    lkv 2 $1 "$val"
}

##############################################################################
### Define variable level 1 and interpret as boolean
### $1 - Variable base name
### $2 - Counter level 1
##############################################################################
function var1bool {
    eval local val="\$${1}_${2}"
    eval $1=$(bool "$val")
    lkb 2 $1 "$val"
}

##############################################################################
### Define variable level 2 and interpret as boolean
### $1 - Variable base name
### $2 - Counter level 1
### $3 - Counter level 2
##############################################################################
function var2bool {
    eval local val="\$${1}_${2}_${3}"
    eval $1=$(bool "$val")
    lkb 2 $1 "$val"
}

##############################################################################
### Wrapper function to add more than one command to "trap ... 0"
### Builds a queue of commands to execute on script exit (signal 0)
### http://stackoverflow.com/a/21212552
### Usage: on_exit "command ..."
##############################################################################
function on_exit_init {
    local next="$1"
    eval "function on_exit {
        local new=\"$(echo "$next" | sed -e s/\'/\'\\\\\'\'/g); \$1\"
        trap -- \"\$new\" 0
        on_exit_init \"\$new\"
    }"
}

### Initialize wrapper, required to declare 1st "on_exit" function
on_exit_init true

##############################################################################
### Remove given file name on script exit
### $1 - file name
##############################################################################
function on_exit_rm () {
    [ "$1" ] && on_exit 'rm -f "'$1'" >/dev/null 2>&1'
}

##############################################################################
### Make a temporary file
### $1 - Variable name
##############################################################################
function temp_file {
    local file=$(mktemp $RUNDIR/pvlng.XXXXXX)
    if [ "$1" ]; then
        on_exit_rm "$file"
        eval ${1}=\$file
    else
        echo $file
    fi
}

##############################################################################
### Build unique key name from configuration file name
### $1 - Prefix, mostly calling script name
### $2 - Id, mostly the configuration file name
### $3 - Additional identifier; optional
##############################################################################
function key_name {
    ### Remove extension from $2 and replace all not allowed chars with single _
    local config=$(echo $(basename "$2") | sed 's~[.].*$~~g;s~[^A-Za-z0-9-]~_~g;s~_+~_~g')
    name="$1.$config"
    [ "$3" ] && name="$name.$3"
    echo $name
}

##############################################################################
### Build run file name from configuration file name
### $1 - Prefix, mostly calling script name
### $2 - Id, e.g. a configuration file name
### $3 - File extension; optional, default ".run"
### $4 - Put this into run file if not exists yet; optional
##############################################################################
function run_file {
    local file="$RUNDIR/$(key_name "$1" "$2" "${3:-run}")"

    lkv 2 "Run file" "$file"

    ### If a 4th parameter was provided, create file with $4 as initial content
    [ $# -eq 4 -a ! -f "$file" ] && echo -ne "$4" >$file
    echo $file
}

##############################################################################
### Build lock file name, create lock link if not esists
### Add a trap for script exit to remove lock file
### $1 - suffix for lock file name, required; for empty use ""
### $2 <> "" and lock file exists (another instance is running)
###          use as exit code
##############################################################################
function check_lock {
    ### Skip check in test mode
    [ "$TEST" ] && return

    local file=$RUNDIR/$(echo $(basename "$0") | \
               sed -e 's~[.].*$~~g' -e 's~[^A-Za-z0-9-]~_~g')$([ "$1" ] && echo ".$1").pid

    lkv 2 "Lock file" $file

    ### Try to create fake link file as lock file
    ln -s pid=$$ $file 2>/dev/null

    if [ $? -eq 0 ]; then
        ### Link not existed yet, remove on script end
        on_exit_rm "$file"
    else
        ### Link exists, check if the process mentioned still runs
        local pid=$(stat -c %N "$file" | sed "s~.*pid=\([0-9]*\).*~\1~g")
        if ps x | sed 's/^ *//' | cut -d' ' -f1 | grep "$pid" | grep -qv grep; then
            log 2 "Lock file exists, process $pid still runs, exit"
            exit ${2:-0}
        else
            log 2 "Lock file exists, process $pid missing, purge lock"
            rm "$file"
        fi
    fi
}

##############################################################################
### Check for daylight times +- offset
### Exit script with rc 127 if not
### $1 - grace period before/after sunrise/sunset in minutes
##############################################################################
function check_daylight {
    local daylight=$(PVLngGET "daylight/${1:-0}.txt")
    lkb 2 Daylight $daylight

    [ "$TEST" -o $daylight -eq 1 ] || exit 127
}

##############################################################################
### Exit script in test mode
### $1 - Exit code; optional, default 0
##############################################################################
function test_exit {
    [ "$TEST" ] && exit ${1:-0}
}

##############################################################################
### Analyse verbosity level and set curl to silent or verbose
##############################################################################
function curl_cmd {
    local mode='--silent' ### default
    [ $(int "$VERBOSE") -gt 2 ] && mode='--verbose'
    ### Always follow 3XX redirects
    echo "$CURL $mode $CurlOpts --location"
}

##############################################################################
### Quote data for JSON requests
### $1 = data string
##############################################################################
function JSON_quote {
    ### Quote " to \\"
    echo "$1" | sed -e 's~"~\\"~g' -e 's/^ *//' -e 's/ *$//'
}

##############################################################################
### Save a log message to PVLng
### $1 = scope
### $2 = message
##############################################################################
function save_log {
    local scope=$(JSON_quote "$1")
    local message=

    ### detect @filename or "normal string" to post
    if [ "${2:0:1}" == '@' ]; then
        message=$(JSON_quote "$(<${2:1})")
    else
        message=$(JSON_quote "$2")
    fi

    lkv 1 Scope "$scope"
    lkv 1 Message "$message"

    $(curl_cmd) --request PUT \
                --header "X-PVLng-key: $PVLngAPIkey" \
                --header "Content-Type: application/json" \
                --data "{\"scope\":\"$scope\",\"message\":\"$message\"}" \
                $PVLngURL/log >/dev/null
}

##############################################################################
### Get latest data from PVLng Socket Server
### $1 = GUID or GUID,<attribute>
##############################################################################
function PVLngNC {
    echo "$1" | netcat $PVLngDomain $SocketServerPort 2>/dev/null
    echo $?
}

##############################################################################
### Save a value for a key persistent into data store
### $1 = Key
### $2 = Value
##############################################################################
function PVLngStorePUT {
    local key=$(echo "$1" | tr . -)
    local value=$2

    if [ "${value:0:1}" != "@" ]; then
        ### No file, quote raw data
        data="[\"$(JSON_quote "$value")\"]"
        sec 2 "Store data"
        lkv 2 $key "$value"
        lkv 2 "Send data" "$data"
    else
        ### File
        data=$value
        log 2 $data "Send file"
    fi

    [ "$TEST" ] && return

    temp_file _RESPONSE

    rc=$($(curl_cmd) --header "X-PVLng-key: $PVLngAPIkey" \
                     --header "Content-Type: application/json" \
                     --request PUT --write-out %{http_code} --output $_RESPONSE \
                     --data-binary "$data" $PVLngURL/store/$key.json)

    if echo "$rc" | grep -qe '^201'; then
        ### 200/201/202 ok
        lkv 2 "HTTP code" $rc
    else
        ### errors
        lkv 0 "HTTP code" $rc
        log 0 @$_RESPONSE Response
        log 0 $data
    fi
}

##############################################################################
### Get a value for a key from data store
### $1 = Key
### $2 = Default value if empty
##############################################################################
function PVLngStoreGET {
    local key=$(echo "$1" | tr . -)
    local default=$2
    local val=$($(curl_cmd) --header "X-PVLng-key: $PVLngAPIkey" $PVLngURL/store/$key.txt)
    echo ${val:-$default}
}

##############################################################################
### Get channel attribute value and buffer it for next calls
### $1 = GUID
### $2 = Attribute & variable name
### $3 - Flag to keep the data as file inside run dir
### Result is a setted global variable of attribute name (case-sensitive!)
### example: PVLngChannelAttr $GUID NAME > $NAME=...
### If in directory of the calling script a file .read exists, the script is
### a data analysing script, the attribute will then NOT buffered into a file.
### Only for data aquisition scripts for the case, that the connection to PVLng
### API is broken.
##############################################################################
function PVLngChannelAttr {
    local GUID=$1
    local attr=${2,,} ### lowercase

    if [ "$3" -o ! -f "$pwd/.read" ]; then
        ### Keep data in file
        local file=$(run_file $GUID $attr txt)
        ### If file is older than 1 day, delete to force re-read
        if [ -f "$file" ]; then
            [ $(calc "($(stat -c %Z $file) + 60*60*24) >= $(now)" 0) -eq 0 ] && rm "$file"
        fi
        if [ ! -f "$file" ]; then
            PVLngGET channel/$GUID/$attr.txt >$file
        fi
        eval $2='$(<$file)'
    else
        eval $2='$(PVLngGET channel/$GUID/$attr.txt)'
    fi
}

##############################################################################
### Get channel attribute value as boolean (0|1)
### See PVLngChannelAttr above
##############################################################################
function PVLngChannelAttrBool {
    PVLngChannelAttr $@
    eval local v=\$$2
    eval $2=$(bool "$v")
}

##############################################################################
### Get data from PVLng latest API release
### $1 = GUID plus add. parameters
##############################################################################
function PVLngGET {
    local url="$PVLngURL/$1"
    lkv 2 'Fetch URL' $url
    $(curl_cmd) --header "X-PVLng-key: $PVLngAPIkey" $url
}

##############################################################################
### Save data to PVLng latest API release
### $1 = GUID
### $2 = value or @file_name with JSON data
### $3 = timestamp
##############################################################################
function PVLngPUT {
    local GUID=$1
    local raw="$2"
    local data="$2"
    local timestamp=$3
    local dataraw=
    local datafile=

    sec 2 "API PUT data"
    lkv 2 GUID $GUID

    ### Skip empty data
    if [ -z "$data" ]; then
        log 2 "Skip empty data"
        return
    fi

    lkv 2 Data "$data"

    if [ "${data:0:1}" != "@" ]; then
        ### No file
        dataraw="$data"
        if [ "$timestamp" ]; then
            ### Given timestamp
            if echo "$timestamp" | grep -qe '[^0-9]'; then
                ### Date time
                lkv 2 'Datetime given' "$timestamp"
            else
                ### numeric timestamp
                lkv 2 'Timestamp given' "$(date --date="@$timestamp")"
            fi
            data="{\"data\":\"$(JSON_quote "$data")\",\"timestamp\":\"$timestamp\"}"
        elif [ $LocalTime == 0 ]; then
            ### Only data, use timestamp from destination
            data="{\"data\":\"$(JSON_quote "$data")\"}"
        else
            ### Send local timestamp rounded to $LocalTime secods
            lkv 1 "Use local time" "rounded to $LocalTime seconds"
            ### force floor of division part, awk have no "round()" or "floor()"
            timestamp=$(calc "int($(date +%s) / $LocalTime) * $LocalTime" 0)
            lkv 2 'Timestamp local' "$(date --date=@$timestamp)"
            data="{\"data\":\"$(JSON_quote "$data")\",\"timestamp\":\"$timestamp\"}"
        fi
        lkv 2 Send "$data"
    else
        ### File
        datafile="${data:1}"
        log 2 "Send file"
        log 2 @$datafile
    fi

    [ "$TEST" ] && return

    ### Log data
    if [ "$SAVEDATA" ]; then
        if [ "$dataraw" ]; then
            _saveRaw "" $GUID $dataraw
        elif [ "$datafile" ]; then
            _saveFile "" $GUID $datafile
        fi
    fi

#    ### For debugging only, register a "request bin" before at http://requestb.in/
#    binUrl=http://requestb.in/...
#    $(curl_cmd) --header "Content-Type: application/json" \
#                --header "X-URL-for: $PVLngURL/data/$GUID.txt" \
#                --request PUT --data-binary $data $binUrl >/dev/null 2>&1

    ### Try to send to Queue server
    if [ "$SocketServerPort" ]; then
        if [ ! "$datafile" ]; then
            rc=$(PVLngNC "SaveData|$GUID|$data")
        else
            rc=$(PVLngNC "SaveData|$GUID|$(<$datafile)")
        fi
        [ $rc -eq 0 ] && return
    fi

    temp_file _RESPONSE

    set -- $($(curl_cmd) --header "X-PVLng-key: $PVLngAPIkey" \
                         --header "Content-Type: application/json" \
                         --request PUT --write-out %{http_code} --output $_RESPONSE \
                         --data-binary "$data" $PVLngURL/data/$GUID.txt)

    if echo "$1" | grep -qe '^20[012]'; then
        ### 200/201/202 ok
        lkv 1 "HTTP code" $1
        [ -f $_PUTRESPONSEFILE ] && log 2 @$_RESPONSE Response
    else
        ### errors
        lkv 0 Data "$data"
        lkv 0 "HTTP code" $1
        [ -f $_PUTRESPONSEFILE ] && log 0 @$_RESPONSE Response
        save_log "$GUID" "HTTP code: $1"
        [ -f $_PUTRESPONSEFILE ] && save_log "$GUID" @$_RESPONSE

        ### Log always failed data
        if [ "$dataraw" ]; then
            _saveRaw "/fail" $GUID $dataraw
            save_log "$GUID" "$dataraw"
        elif [ "$datafile" ]; then
            _saveFile "/fail" $GUID $datafile
            save_log "$GUID" "@$datafile"
        fi
    fi
}

##############################################################################
### Save raw data to PVLng latest API release
### $1 = GUID
### $2 = @file_name with raw data
##############################################################################
function PVLngPUTraw {
    local GUID="$1"
    local data="$2"
    local datafile=

    lkv 2 GUID $GUID
    lkv 2 Data $data

    if test "${data:0:1}" != "@"; then
        ### No file
        error_exit "PVLngPUTraw require @<filename> as 2nd parameter!"
    else
        ### File
        datafile="${data:1}"
        log 2 "Send file :"
        log 2 @$datafile
    fi

    [ "$TEST" ] && return

    ### Log data
    [ "$SAVEDATA" ] && _saveFile "" $GUID $datafile

    temp_file _RESPONSE

    set -- $($(curl_cmd) --header "X-PVLng-key: $PVLngAPIkey" \
                         --request PUT --write-out %{http_code} --output $_RESPONSE \
                         --data-binary $data $PVLngURL/data/raw/$GUID.txt)

    if echo "$1" | grep -qe '^20[012]'; then
        ### 200/201/202 ok
        lkv 1 "HTTP code" $1
        [ -f $_RESPONSE ] && log 2 @$_RESPONSE Response
    else
        ### errors
        lkv 0 "HTTP code" $1
        [ -f $_RESPONSE ] && log 0 @$_RESPONSE Response
        save_log "$GUID" "HTTP code: $1"
        [ -f $_RESPONSE ] && save_log "$GUID" @$_RESPONSE

        ### Log always failed data
        _saveFile "/fail" $GUID $datafile
        save_log "$GUID" "@$datafile"
    fi
}

##############################################################################
### Save data to PVLng using batch
### $1 = GUID
### $2 = file - @file_name
###      <timestamp>,<value>;...   : Semicolon separated timestamp and value data sets
###      <date time>,<value>;...   : Semicolon separated date time and value data sets
###      <date>,<time>,<value>;... : Semicolon separated date, time and value data sets
##############################################################################
function PVLngPUTBatch {
    local GUID="$1"
    local data="$2"

    lkv 2 GUID $GUID
    lkv 2 "Data file" "$data"

    [ "$TEST" ] && return

    temp_file _RESPONSE

    set -- $($(curl_cmd) --header "X-PVLng-key: $PVLngAPIkey" \
                         --header "Content-Type: text/plain" \
                         --request PUT --write-out %{http_code} --output $_RESPONSE \
                         --data-binary $data $PVLngURL/batch/$GUID.txt)

    if echo "$1" | grep -qe '^20[012]'; then
        ### 200/201/202 ok
        lkv 1 "HTTP code" $1
        [ -f $_RESPONSE ] && log 2 @$_RESPONSE Response
    else
        ### errors
        lkv 0 "HTTP code" $1
        [ -f $_RESPONSE ] && log -1 @$_RESPONSE Response
        save_log "$GUID" "HTTP code: $1 - raw: $raw"
        [ -f $_RESPONSE ] && save_log "$GUID" @$_RESPONSE
    fi

}

##############################################################################
### Save data to PVLng using CSV file
### $1 = GUID
### $2 = CSV file - @file_name
###      <timestamp>;<value>   : Semicolon separated timestamp and value data rows
###      <date time>;<value>   : Semicolon separated date time and value data rows
###      <date>;<time>;<value> : Semicolon separated date, time and value data rows
##############################################################################
function PVLngPUTCSV {
    local GUID="$1"
    local data="$2"

    lkv 2 GUID $GUID
    lkv 2 "Data file" "$data"

    [ "$TEST" ] && return

    temp_file _RESPONSE

    set -- $($(curl_cmd) --header "X-PVLng-key: $PVLngAPIkey" \
                         --header "Content-Type: text/plain" \
                         --request PUT --write-out %{http_code} --output $_RESPONSE \
                         --data-binary $data $PVLngURL/csv/$GUID.txt)

    if echo "$1" | grep -qe '^20[012]'; then
        ### 200/201/202 ok
        lkv 1 "HTTP code" $1
        [ -f $_RESPONSE ] && log 2 @$_RESPONSE Response
    else
        ### errors
        lkv 0 "HTTP code" $1
        [ -f $_RESPONSE ] && log -1 @$_RESPONSE Response
        save_log "$GUID" "HTTP code: $1 - raw: $raw"
        [ -f $_RESPONSE ] && save_log "$GUID" @$_RESPONSE
    fi
}

##############################################################################
### internal use
### $1 = directory
### $2 = GUID
### $3 = value
##############################################################################
function _saveRaw {
    ### Each GUID get its own directory
    local dir=${SAVEDATADIR}${1}/${2}/$(date +"%Y-%m")
    local file=${dir}/$(date +"%Y-%m-%d").csv
    local data="$3"

    log 2 "Save '$data' to $file"

    [ -d $dir ] || mkdir -p $dir
    echo $(date +"%Y-%m-%d %H:%M:%S")";$data" >>$file
    chmod 600 $file
}

##############################################################################
### Internal use
### $1 = directory
### $2 = GUID
### $3 = @file_name with data
##############################################################################
function _saveFile {
    ### Multiple files per day, each day of GUID get its own directory
    local dir=${SAVEDATADIR}${1}/${2}/$(date +"%Y-%m/%d")
    local file=${dir}/$(date +"%Y-%m-%d.%H:%M:%S")
    local data="$3"

    log 2 "Save data"
    log 2 "- from $data"
    log 2 "-   to $file"

    [ -d $dir ] || mkdir -p $dir
    cp "$data" $file
    chmod 600 $file
}

##############################################################################
### Exit with error message and return code 1
### http://curl.haxx.se/libcurl/c/libcurl-errors.html
### $1 - Error code return by curl
### $2 - Error context text
##############################################################################
function curl_error_exit {
    rc=$1
    local -a curl_rc=
    curl_rc[1]="The URL you passed to libcurl used a protocol that this libcurl does not support. The support might be a compile-time option that you didn't use, it can be a misspelled protocol string or just a protocol libcurl has no code for."
    curl_rc[2]="Very early initialization code failed. This is likely to be an internal error or problem, or a resource problem where something fundamental couldn't get done at init time."
    curl_rc[3]="The URL was not properly formatted."
    curl_rc[4]="A requested feature, protocol or option was not found built-in in this libcurl due to a build-time decision. This means that a feature or option was not enabled or explicitly disabled when libcurl was built and in order to get it to function you have to get a rebuilt libcurl."
    curl_rc[5]="Couldn't resolve proxy. The given proxy host could not be resolved."
    curl_rc[6]="Couldn't resolve host. The given remote host was not resolved."
    curl_rc[7]="Failed to connect() to host or proxy."
    curl_rc[8]="After connecting to a FTP server, libcurl expects to get a certain reply back. This error code implies that it got a strange or bad reply. The given remote server is probably not an OK FTP server."
    curl_rc[9]="We were denied access to the resource given in the URL. For FTP, this occurs while trying to change to the remote directory."
    curl_rc[10]="While waiting for the server to connect back when an active FTP session is used, an error code was sent over the control connection or similar."
    curl_rc[11]="After having sent the FTP password to the server, libcurl expects a proper reply. This error code indicates that an unexpected code was returned."
    curl_rc[12]="During an active FTP session while waiting for the server to connect, the CURLOPT_ACCEPTTIMOUT_MS (or the internal default) timeout expired."
    curl_rc[13]="libcurl failed to get a sensible result back from the server as a response to either a PASV or a EPSV command. The server is flawed."
    curl_rc[14]="FTP servers return a 227-line as a response to a PASV command. If libcurl fails to parse that line, this return code is passed back."
    curl_rc[15]="An internal failure to lookup the host used for the new connection."
    curl_rc[17]="Received an error when trying to set the transfer mode to binary or ASCII."
    curl_rc[18]="A file transfer was shorter or larger than expected. This happens when the server first reports an expected transfer size, and then delivers data that doesn't match the previously given size."
    curl_rc[19]="This was either a weird reply to a 'RETR' command or a zero byte transfer complete."
    curl_rc[21]="When sending custom 'QUOTE' commands to the remote server, one of the commands returned an error code that was 400 or higher (for FTP) or otherwise indicated unsuccessful completion of the command."
    curl_rc[22]="This is returned if CURLOPT_FAILONERROR is set TRUE and the HTTP server returns an error code that is >= 400."
    curl_rc[23]="An error occurred when writing received data to a local file, or an error was returned to libcurl from a write callback."
    curl_rc[25]="Failed starting the upload. For FTP, the server typically denied the STOR command. The error buffer usually contains the server's explanation for this."
    curl_rc[26]="There was a problem reading a local file or an error returned by the read callback."
    curl_rc[27]="A memory allocation request failed. This is serious badness and things are severely screwed up if this ever occurs."
    curl_rc[28]="Operation timeout. The specified time-out period was reached according to the conditions."
    curl_rc[30]="The FTP PORT command returned error. This mostly happens when you haven't specified a good enough address for libcurl to use. See CURLOPT_FTPPORT."
    curl_rc[31]="The FTP REST command returned error. This should never happen if the server is sane."
    curl_rc[33]="The server does not support or accept range requests."
    curl_rc[34]="This is an odd error that mainly occurs due to internal confusion."
    curl_rc[35]="A problem occurred somewhere in the SSL/TLS handshake. You really want the error buffer and read the message there as it pinpoints the problem slightly more. Could be certificates (file formats, paths, permissions), passwords, and others."
    curl_rc[36]="The download could not be resumed because the specified offset was out of the file boundary."
    curl_rc[37]="A file given with FILE:// couldn't be opened. Most likely because the file path doesn't identify an existing file. Did you check file permissions?"
    curl_rc[38]="LDAP cannot bind. LDAP bind operation failed."
    curl_rc[39]="LDAP search failed."
    curl_rc[41]="Function not found. A required zlib function was not found."
    curl_rc[42]="Aborted by callback. A callback returned 'abort' to libcurl."
    curl_rc[43]="Internal error. A function was called with a bad parameter."
    curl_rc[45]="Interface error. A specified outgoing interface could not be used. Set which interface to use for outgoing connections' source IP address with CURLOPT_INTERFACE."
    curl_rc[47]="Too many redirects. When following redirects, libcurl hit the maximum amount. Set your limit with CURLOPT_MAXREDIRS."
    curl_rc[48]="An option passed to libcurl is not recognized/known. Refer to the appropriate documentation. This is most likely a problem in the program that uses libcurl. The error buffer might contain more specific information about which exact option it concerns."
    curl_rc[49]="A telnet option string was Illegally formatted."
    curl_rc[51]="The remote server's SSL certificate or SSH md5 fingerprint was deemed not OK."
    curl_rc[52]="Nothing was returned from the server, and under the circumstances, getting nothing is considered an error."
    curl_rc[53]="The specified crypto engine wasn't found."
    curl_rc[54]="Failed setting the selected SSL crypto engine as default!"
    curl_rc[55]="Failed sending network data."
    curl_rc[56]="Failure with receiving network data."
    curl_rc[58]="Problem with the local client certificate."
    curl_rc[59]="Couldn't use specified cipher."
    curl_rc[60]="Peer certificate cannot be authenticated with known CA certificates."
    curl_rc[61]="Unrecognized transfer encoding."
    curl_rc[62]="Invalid LDAP URL."
    curl_rc[63]="Maximum file size exceeded."
    curl_rc[64]="Requested FTP SSL level failed."
    curl_rc[65]="When doing a send operation curl had to rewind the data to retransmit, but the rewinding operation failed."
    curl_rc[66]="Initiating the SSL Engine failed."
    curl_rc[67]="The remote server denied curl to login (Added in 7.13.1)"
    curl_rc[68]="File not found on TFTP server."
    curl_rc[69]="Permission problem on TFTP server."
    curl_rc[70]="Out of disk space on the server."
    curl_rc[71]="Illegal TFTP operation."
    curl_rc[72]="Unknown TFTP transfer ID."
    curl_rc[73]="File already exists and will not be overwritten."
    curl_rc[74]="This error should never be returned by a properly functioning TFTP server."
    curl_rc[75]="Character conversion failed."
    curl_rc[76]="Caller must register conversion callbacks."
    curl_rc[77]="Problem with reading the SSL CA cert (path? access rights?)"
    curl_rc[78]="The resource referenced in the URL does not exist."
    curl_rc[79]="An unspecified error occurred during the SSH session."
    curl_rc[80]="Failed to shut down the SSL connection."
    curl_rc[81]="Socket is not ready for send/recv wait till it's ready and try again. This return code is only returned from curl_easy_recv(3) and curl_easy_send(3) (Added in 7.18.2)"
    curl_rc[82]="Failed to load CRL file (Added in 7.19.0)"
    curl_rc[83]="Issuer check failed (Added in 7.19.0)"
    curl_rc[84]="The FTP server does not understand the PRET command at all or does not support the given argument. Be careful when using CURLOPT_CUSTOMREQUEST, a custom LIST command will be sent with PRET CMD before PASV as well. (Added in 7.20.0)"
    curl_rc[85]="Mismatch of RTSP CSeq numbers."
    curl_rc[86]="Mismatch of RTSP Session Identifiers."
    curl_rc[87]="Unable to parse FTP file list (during FTP wildcard downloading)."
    curl_rc[88]="Chunk callback reported error."

    echo
    echo $scriptname: Curl error $2 "($rc): ${curl_rc[$rc]}" 1>&2
    echo
    exit 1
}

##############################################################################
### Exit with error message and return code 127
##############################################################################
function error_exit {
    ### Display error message and usage and exit
    echo
    echo "ERROR: ${1:-"Unknown Error"}" 1>&2
    usage
    exit ${2:-127}
}

##############################################################################
### Exit with error message for required variable
##############################################################################
function exit_required {
    error_exit "$1 required ($2)!"
}

##############################################################################
###
##############################################################################
function realpath {
    local f=$@;
    local base=
    local dir=

    if [ -d "$f" ]; then
        base="";
        dir="$f";
    else
        base="/$(basename "$f")";
        dir=$(dirname "$f");
    fi

    ### $() run in sub shell...
    dir=$(cd "$dir" && /bin/pwd);
    echo "$dir$base"
}

##############################################################################
### urlencode <string>
### https://gist.github.com/cdown/1163649
### $1 - String to encode
##############################################################################
function urlencode {
    local length=${#1}
    local c=

    for ((i=0; i<length; i++)); do
        c="${1:i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) printf "$c" ;;
            *)               printf '%%%02X' "'$c"
        esac
    done
}

##############################################################################
### Transform XML file to JSON
### $1 - XML file name
##############################################################################
function xml2json {
    php -r "echo json_encode(simplexml_load_string(file_get_contents('$1')));"
}

##############################################################################
### JSON query
### $1 - JSON string or @filename
### $2 - Query in object notation like "messages[0]->message"
##############################################################################
function jq {
    local json=$1
    [ "${1:0:1}" == @ ] && json=$(<${1:1})
    php -r "\$d=json_decode('$json'); if (\$d && isset(\$d->$2)) echo \$d->$2;"
}

##############################################################################
### Show run time of script
### $1 - Verbose level, default 2
### $2 - Custom title for output in between scripts, default "Run time"
##############################################################################
function run_time {

    local level=${1:-2}

    [ $VERBOSE -ge $level ] || return

    ### Time gone since script start
    local t=$(calc "$(now) - $REQUEST_TIME")
    ### Full seconds (integer) for further checks
    local s=$(toFixed $t)

    if [ $s -lt 10 ]; then
        ### In milli seconds below 10 sec
        t="$(calc "$t * 1000" 1) ms"
    elif [ $s -lt 60 ]; then
        ### In seconds below 60 sec
        t=$(printf "%.1f s" $t)
    elif [ $s -lt 3600 ]; then
        ### In minutes below an hour
        t="$(calc "$t / 60" 1) min"
    else
        ### In hours otherwise
        t="$(calc "$t / 3600" 1) h"
    fi

    lkv 0 "${2:-Run time}" "$t"
}

##############################################################################
### Default PVLng script options
##############################################################################
function opt_define_pvlng {
    ### Test mode with raise of verbosity level
    ### Value is required to detect argument as flag
    opt_define short=c long=config variable=CONFIG \
               desc='Config file' default="$CONFIG"
    if [ "$1" ]; then
        ### Use local time or round to -l ? seconds
        opt_define short=l long=localtime variable=LocalTime default=0 \
                   desc='Use local time, rounded to ? seconds'
        ### Flag to save data also into file
        opt_define short=s long=save variable=SAVEDATA value=y \
                   desc='Save data also into log file'
    fi
    ### Test mode with raise of verbosity level
    ### Value is required to detect argument as flag
    opt_define short=t long=test variable=TEST value=y \
               desc='Test mode, set verbosity to info level' \
               callback='TEST=y; VERBOSE=$(($VERBOSE+1))'
    ### Multiple -v raises verbosity level
    opt_define_verbose
    ### Prepare a hidden TRACE variable to "set -x" after preparation
    ### No description, not shown in help
    opt_define_trace
}

##############################################################################
function now {
    date +%s.%N
}

##############################################################################
### Init
##############################################################################
LC_NUMERIC=C

_ROOT=$(readlink -f $(dirname ${BASH_SOURCE[0]}))

if [ ! -f $_ROOT/PVLng.conf ]; then
    echo "You haven't a configuration file '$_ROOT/PVLng.conf' yet!"
    cp $_ROOT/PVLng.conf.dist $_ROOT/PVLng.conf
    echo I made one for you, you have to maintain it now...
    exit 2
fi

### Scripts disabled?
[ -f $_ROOT/.paused ] && exit 254

### Load global configuration
. $_ROOT/PVLng.conf

### Source getopts helper functions
. $_ROOT/opt.sh

### Latest API release
PVLngURL="$PVLngHost/api/latest"

### Setup curl command
: ${CURL:=$(which curl 2>/dev/null)}
[ "$CURL" ] || error_exit "Can not find curl executable, please install and/or define in PVLng.conf!" 1
CURL="$CURL $CURLCONNECT"

### Show run time on end from verbose level 1 onwards
on_exit "run_time"

### Directory for the temporary "run" files
RUNDIR=${RunDir:-$_ROOT/run}
[ -d "$RUNDIR" ] || mkdir -p "$RUNDIR"

### Automatic logging of all data pushed to PVLng API,
### Flag -s|--savedata required
SAVEDATADIR=${SaveDataDir:-$_ROOT/data}

### Some variables
scriptname=${0##*/}

### Don't use local time
LocalTime=0

### Create temp. file e.g. for curl --output and remove on exit
temp_file TMPFILE

VERBOSE=0

CONFIG=$(echo "$0" | sed 's~\.[^.]*$~.conf~g')
