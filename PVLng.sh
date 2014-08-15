##############################################################################
### @author      Knut Kohl <github@knutkohl.de>
### @copyright   2012-2013 Knut Kohl
### @license     GNU General Public License http://www.gnu.org/licenses/gpl.txt
### @version     $Id$
##############################################################################

REQUEST_TIME=$(date +%s)

##############################################################################
### show message depending of verbosity level on stderr
##############################################################################
function log {
    test $VERBOSE -ge $1 || return
    shift
    d="["$(date +"%H:%M:%S.%N" | cut -b-12)"]"
    {   ### Detect if now $1 is a "@filename"
        if test "${1:0:1}" == '@'; then
            file=${1:1}
            # echo "$d $file >>>"
            ### cat ... read needs at least one new line at end of file...
            echo >>$file
            cat $file | sed '/^$/d' | while read l; do echo "$d $l"; done
            # echo "$d <<< $file"
        else
            echo -e "$d $*"
        fi
    } >&2
}

##############################################################################
### show usage
### requires a section of text enclosed by
### # USAGE >>
### ...
### # << USAGE
##############################################################################
function usage {
    s=$(cat "$0" | \
        awk '{if($0~/^#+ +USAGE +>+/){while(getline>0){if($0~/^#+ *<+ *USAGE/)exit;print $0}}}')
    eval s="$(echo \""$s"\")"
    echo "$s" >&2
}

##############################################################################
### read config file
##############################################################################
function read_config {
    local file="$1"

    if test -z "$file"; then
        echo
        echo ERROR: Configuration file required!
        usage
        exit 1
    fi

    test -f "$file" || file="$(dirname $0)/$file"
    if test ! -r "$file"; then
        echo
        echo ERROR: Configuration file is not readable!
        usage
        exit 1
    fi

    log 2 "--- $file ---"

    while read var value; do
        test -n "$var" -a "${var:0:1}" != '#' || continue
        value=$(echo -e "$value" | sed -e 's/^"[ \t]*//g' -e 's/[ \t]*"$//g')
        log 2 "$(printf '%-20s = %s' $var "$value")"
        eval "$var=\$value"
    done <"$file"
}

##############################################################################
### Force $1 as boolean
### Any of 1,x,on,yes,true is case-insensitive detected as TRUE
### Return 1 for TRUE, 0 for FALSE
##############################################################################
function bool {
    case $(echo "$1" | tr [:upper:] [:lower:]) in
        1|x|on|yes|true) echo 1 ;;
        *)               echo 0 ;;
    esac
}

##############################################################################
### Force $1 as integer
### Return 0 for invalid/empty parameter $1
##############################################################################
function int {
    local t=
    test -n "$1" && t=$(expr "$1" \* 1 2>/dev/null)
    test -z "$t" && echo 0 || echo $t
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
### Build md5 hash of file
##############################################################################
function hash {
    md5sum "$1" | cut -d' ' -f1
}

##############################################################################
### Define variable level 1
### Example: var1 GUID 1 > $GUID will get value of $GUID_1
##############################################################################
function var1 {
    eval ${1}="\$${1}_${2}"
}

##############################################################################
### Define variable level 2
### example: var2 ACTION 1 1 > $ACTION will get value of $ACTION_1_1
##############################################################################
function var2 {
    eval ${1}="\$${1}_${2}_${3}"
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
        local old='$(echo "$next" | sed -e s/\'/\'\\\\\'\'/g)'
        local new=\"\$old; \$1\"
        trap -- \"\$new\" 0
        on_exit_init \"\$new\"
    }"
}
### Initialize wrapper, required to declare 1st "on_exit" function
on_exit_init true

##############################################################################
### Remove given file name on script exit
### $1 : file name
##############################################################################
function on_exit_rm {
    test "$1" && on_exit 'rm -f "'$1'" >/dev/null 2>&1'
}

##############################################################################
### Build run file name from configuration file name
### $1 - Prefix, mostly calling script name
### $2 - e.g. a configuration file name
### $3 - File extension, optional; default "run"
##############################################################################
function run_file {                           ### remove extension, replace all not allowed chars with single _
    echo $RUNDIR/$1.$(echo $(basename "$2") | sed -e 's~[.].*$~~g' -e 's~[^A-Za-z0-9-]~_~g' -e 's~_+~_~g').${3:-run}
}

##############################################################################
### Build lock file name, create lock link if not esists
### Add a trap for script exit to remove lock file
### $1 - suffix for lock file name, required; for empty use ""
### $2 <> "" and lock file exists (another instance is running) 
###          use as exit code
##############################################################################
function check_lock {
    local lockfile=$RUNDIR/$(echo $(basename "$0") | sed -e 's~[.].*$~~g' -e 's~[^A-Za-z0-9-]~_~g')$(test "$1" && echo ".$1").pid

    log 2 "Lock file : $lockfile"

    if [ -L $lockfile ]; then
        exit ${2:-0}
    else
        ### Make fake link file as lock file
        ln -s pid=$$ $lockfile
        on_exit_rm "$lockfile"
    fi
}

##############################################################################
### Make a temporary file
##############################################################################
function temp_file {
    mktemp /tmp/pvlng.XXXXXX
}

##############################################################################
### Analyse verbosity level and set curl to silent or verbose
##############################################################################
function curl_cmd {
    local mode='--silent' # default
    test $(int "$VERBOSE") -gt 2 && mode='--verbose'
    echo "$CURL $mode $CurlOpts"
}

##############################################################################
### Quote data for JSON requests
### $1 = data string
##############################################################################
function JSON_quote {
    ### Quote " to \\"
    echo "$1" | sed -e 's~"~\\"~g'
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
    if test "${2:0:1}" == '@'; then
        message=$(JSON_quote "$(<${2:1})")
    else
        message=$(JSON_quote "$2")
    fi

    log 1 "Scope   : $scope"
    log 1 "Message : $message"

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
    echo "$1" | netcat $PVLngDomain $SocketServerPort
}

##############################################################################
### Get channel attribute value
### $1 = GUID
### $2 = Attribute & variable name
### Result is a setted global variable of attribute name (case-sensitive!)
### example: PVLngChannelAttr $GUID NAME > $NAME=...
##############################################################################
function PVLngChannelAttr {
    ### convert attribute to lowercase
    local attr=$(echo ${2} | tr [:upper:] [:lower:])
    eval ${2}="$(PVLngGET channel/${1}/${attr}.txt)"
}

##############################################################################
### Get data from PVLng latest API release
### $1 = GUID plus add. parameters
##############################################################################
function PVLngGET {
    local url="$PVLngURL/$1"
    log 2 "Fetch    : $url"
    $(curl_cmd) --header "X-PVLng-key: $PVLngAPIkey" $url
    log 2 "Fetch    : done"
}

##############################################################################
### Save data to PVLng latest API release
### $1 = GUID
### $2 = value or @file_name with JSON data
##############################################################################
function PVLngPUT {
    local GUID="$1"
    local raw="$2"
    local data="$2"
    local dataraw=
    local datafile=

    log 2 "GUID      : $GUID"
    log 2 "Data      : $data"

    if test "${data:0:1}" != "@"; then
        ### No file
        dataraw="$data"
        data="{\"data\":\"$(JSON_quote "$data")\"}"
        log 2 "Send      : $data"
    else
        ### File
        datafile="${data:1}"
        log 2 "Send file :"
        log 2 @$datafile
    fi

    ### Log data
    if test "$SAVEDATA"; then
        if test "$dataraw"; then
            PVLngPUTsaveRaw "$SaveDataDir" $GUID $dataraw
        elif test "$datafile"; then
            PVLngPUTsaveFile "$SaveDataDir" $GUID $datafile
        fi
    fi

    ### Clear temp. file before
    rm $TMPFILE >/dev/null 2>&1

    set $($(curl_cmd) --request PUT \
                      --header "X-PVLng-key: $PVLngAPIkey" \
                      --header "Content-Type: application/json" \
                      --write-out %{http_code} \
                      --output $TMPFILE \
                      --data-binary $data \
                      $PVLngURL/data/$GUID.txt)

    if echo "$1" | grep -qe '^20[012]'; then
        ### 200/201/202 ok
        log 1 "HTTP code : $1"
        test -f $TMPFILE && log 2 @$TMPFILE
    else
        ### errors

        ### Log always failed data
        if test "$dataraw"; then
            PVLngPUTsaveRaw "$SaveDataDir/fail" $GUID $dataraw
        elif test "$datafile"; then
            PVLngPUTsaveFile "$SaveDataDir/fail" $GUID $datafile
        fi

        log -1 "HTTP code : $1"
        test -f $TMPFILE && log -1 @$TMPFILE
        save_log "$GUID" "HTTP code: $1 - raw: $raw"
        test -f $TMPFILE && save_log "$GUID" @$TMPFILE
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

    log 2 "GUID      : $GUID"
    log 2 "Data file : $data"

    ### Clear temp. file before
    rm $TMPFILE >/dev/null 2>&1

    set $($(curl_cmd) --request PUT \
                      --header "X-PVLng-key: $PVLngAPIkey" \
                      --header "Content-Type: text/plain" \
                      --write-out %{http_code} \
                      --output $TMPFILE \
                      --data-binary $data \
                      $PVLngURL/batch/$GUID.txt)

    if echo "$1" | grep -qe '^20[012]'; then
        ### 200/201/202 ok
        log 1 "HTTP code : $1"
        test -f $TMPFILE && log 2 @$TMPFILE
    else
        ### errors
        log -1 "HTTP code : $1"
        test -f $TMPFILE && log -1 @$TMPFILE
        save_log "$GUID" "HTTP code: $1 - raw: $raw"
        test -f $TMPFILE && save_log "$GUID" @$TMPFILE
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

    log 2 "GUID      : $GUID"
    log 2 "Data file : $data"

    ### Clear temp. file before
    rm $TMPFILE >/dev/null 2>&1

    set $($(curl_cmd) --request PUT \
                      --header "X-PVLng-key: $PVLngAPIkey" \
                      --header "Content-Type: text/plain" \
                      --write-out %{http_code} \
                      --output $TMPFILE \
                      --data-binary $data \
                      $PVLngURL/csv/$GUID.txt)

    if echo "$1" | grep -qe '^20[012]'; then
        ### 200/201/202 ok
        log 1 "HTTP code : $1"
        test -f $TMPFILE && log 2 @$TMPFILE
    else
        ### errors
        log -1 "HTTP code : $1"
        test -f $TMPFILE && log -1 @$TMPFILE
        save_log "$GUID" "HTTP code: $1 - raw: $raw"
        test -f $TMPFILE && save_log "$GUID" @$TMPFILE
    fi

}

##############################################################################
### internal use
### $1 = directory
### $2 = GUID
### $3 = value
##############################################################################
function PVLngPUTsaveRaw {
    ### Each GUID get its own directory
    local dir=${1}/${2}/$(date +"%Y-%m")
    local file=${dir}/$(date +"%Y-%m-%d").csv

    log 2 "Save $3 to $file"

    test -d $dir || mkdir -p $dir
    echo $(date +"%Y-%m-%d %H:%M:%S")";$3" >>$file
}

##############################################################################
### internal use
### $1 = directory
### $2 = GUID
### $3 = @file_name with data
##############################################################################
function PVLngPUTsaveFile {
    ### Multiple files per day, each day of GUID get its own directory
    local dir=${1}/${2}/$(date +"%Y-%m/%d")
    local file=${dir}/$(date +"%Y-%m-%d.%H:%M:%S")

    log 2 "Save data"
    log 2 "- from $3"
    log 2 "-   to $file"

    test -d $dir || mkdir -p $dir
    cp "$3" $file
}

##############################################################################
### trap function to clean up
##############################################################################
function clean_up {
:;
    ### Clean up on program exit, accepts an exit status
##    rm -f "$TMPFILE" >/dev/null 2>&1
##    exit $1
}

##############################################################################
### exit with error message and return code 1
##############################################################################
function curl_error_exit {
    ### Display curl error message and exit
    #
    # http://curl.haxx.se/libcurl/c/libcurl-errors.html
    #
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
### Exit with error message and return code 1
##############################################################################
function error_exit {
    ### Display error message and exit
    echo
    echo "$scriptname: ${1:-"Unknown Error"}" 1>&2
    echo
    exit 1
}

##############################################################################
###
##############################################################################
function realpath {
    f=$@;
    if [ -d "$f" ]; then
        base="";
        dir="$f";
    else
        base="/$(basename "$f")";
        dir=$(dirname "$f");
    fi;
    dir=$(cd "$dir" && /bin/pwd);
    echo "$dir$base"
}

##############################################################################
### Show run time of script in seconds/minutes,
### best use with verbose equal/upper info
### $1 = <empty>: Show seconds, else minutes
### Usage: log 1 $(run_time)   # for seconds
###        log 1 $(run_time x) # for minutes
##############################################################################
function run_time {
    if test -z "$1"; then
        printf "Run time : %.0f s" $(echo "($(date +%s) - $REQUEST_TIME)" | bc -l)
    else
        printf "Run time : %.1f min" $(echo "($(date +%s) - $REQUEST_TIME) / 60" | bc -l)
    fi
}

##############################################################################
### Default PVLng script options
##############################################################################
function opt_define_pvlng() {
    if [ "$1" ]; then
        ### Flag to save data also into file
        opt_define short=s long=save desc='Save data also into log file' variable=SAVEDATA value=y
    fi
    ### Test mode with raise of verbosity level
    ### Value is required to detect argument as flag
    opt_define short=t long=test variable=TEST \
               desc='Test mode, set verbosity to info level' value=y \
               callback='TEST=y; VERBOSE=$(($VERBOSE+1))'
    ### Multiple -v raises verbosity level
    opt_define short=v long=verbose variable=VERBOSE \
               desc='Verbosity, use multiple times for higher level' \
               default=0 value=1 callback='VERBOSE=$(($VERBOSE+1))'
    ### Prepare a TRACE variable to "set -x" after preparation
    ### No description > not shown in help
    opt_define short=x long=trace variable=TRACE value=X
}

##############################################################################
### Init
##############################################################################
LC_NUMERIC=en_US

_ROOT=$(readlink -f $(dirname ${BASH_SOURCE[0]}))

### Source getopts helper functions
source $_ROOT/opt.sh

### Load global configuration
source $_ROOT/PVLng.conf

### Latest API release
PVLngURL="$PVLngHost/api/r4"

### Setup curl command
test "$CURL" || CURL="$(which curl 2>/dev/null)"
test -z "$CURL" && echo "Can not find curl executable, please install and/or define in PVLng.conf!" && exit 1

CURL="$CURL $CURLCONNECT"

### Create temp. file e.g. for curl --output and remove on exit
TMPFILE=$(mktemp /tmp/pvlng.XXXXXX)
on_exit_rm "$TMPFILE"

### Some variables
scriptname=${0##*/}

### Automatic logging of all data pushed to PVLng API,
### flag -s, --savedata required
SAVEDATA=
### default directory can be overwriten in any other config file
test "$SaveDataDir" || SaveDataDir=$_ROOT/data

### Directory for the "run" files
RUNDIR=$_ROOT/run
