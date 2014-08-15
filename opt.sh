##############################################################################
### @author      Knut Kohl <github@knutkohl.de>
### @copyright   2012-2013 Knut Kohl
### @license     GNU General Public License http://www.gnu.org/licenses/gpl.txt
### @version     1.0.0
###
### Idea from Optparse - a BASH wrapper for getopts
### @author : nk412 / nagarjuna.412@gmail.com
##############################################################################

_opt_usage=
_opt_cont=
_opt_defs=
_opt_process=
_opt_args=
_opt_req=()
_opt_help=
_opt_help_args=
_opt_help_args_req=
_opt_help_hint=

##############################################################################
### Throw error and halt
##############################################################################
function __opt_error() {
    local message="$1"
    echo "ERROR: $message"
    exit 1
}

##############################################################################
### Helper function
##############################################################################
function __opt_help() {
    _opt_usage+="#TB$(printf "%s, %-20s %s" "$1" "$2" "$3")#NL"
}

##############################################################################
function opt_help() {
    _opt_help="#NL$1#NL"
}

##############################################################################
function opt_help_hint() {
    _opt_help_hint="$1"
}

##############################################################################
function opt_help_args() {
    _opt_help_args="$1"
}

##############################################################################
function opt_define() {
    if [ $# -lt 3 ]; then
        __opt_error 'opt_define short= long= variable= [desc=] [default=] [value=] [callback=] [required]'
    fi

    local option=
    local key=
    local value=
    local short=
    local long=
    local desc=
    local default=
    local variable=
    local callback=
    local required=
    local val='$OPTARG'

    for option in "$@"; do
        key=$( echo "$option" | cut -d= -f1 )
        value="$( echo "$option" | cut -d= -f2- )"

        ### Essentials: shortname, longname, description
        case "$key" in
            short)
                if [ ${#value} -ne 1 ]; then
                    __opt_error "${value}: short name expected to be one character long"
                fi
                short=${value}
                ;;
            long)
                if [ ${#value} -lt 2 ]; then
                    __opt_error "${value}: long name expected to be at least one character long"
                fi
                long=${value}
                ;;
            desc)     desc="$value";;
            default)  default="$value";;
            variable) variable="$value";;
            value)    val="$value";;
            callback) callback="$value";;
            required) required=y;;
        esac
    done

    if [ "$variable" = "" ]; then
        __opt_error "You must give a variable for option: (-$short/--$long)"
    fi

    ### Build help only if description is given
    if [ "$desc" ]; then
        if [ "$val" != "" ]; then
            if [ "$val" != "\$OPTARG" ]; then
                ### Flag parameter
                desc+=" [flag]"
            else
                ### Parameter with default value
                desc+=" [default:${default}]"
            fi
        fi
        if [ "$required" ]; then
            _opt_req+=" $variable:$short"
            _opt_help_args_req+="(-${short}|--${long}) <${long}> "
            desc+=" (required)"
        fi
        __opt_help "-$short" "--$long" "$desc"
    fi

    _opt_cont+="#TB#TB--${long})#NL#TB#TB#TBparams=\"\$params -${short}\";;#NL"

    ### Initialize all variables, also empty once
    _opt_defs+="${variable}=${default}#NL"

    if [ "$val" = "\$OPTARG" ]; then
        ### Option requires parameter
        _opt_args+="${short}:"
    else
        _opt_args+="${short}"
    fi

    if [ "$callback" ]; then
        _opt_process+="#TB#TB${short}) ${callback};;#NL"
    else
        _opt_process+="#TB#TB${short}) ${variable}=\"$val\";;#NL"
    fi
}

##############################################################################
function opt_define_quiet() {
    opt_define short=q long=quiet variable=QUIET desc='Quiet mode' value=1 \
               callback='VERBOSE=-1'
}

##############################################################################
function opt_define_verbose() {
    opt_define short=v long=verbose variable=VERBOSE \
               desc='Verbosity, use multiple times for higher level' \
               default=0 value=1 callback='VERBOSE=$(($VERBOSE+1))'
}

##############################################################################
function opt_define_test() {
    opt_define short=t long=test variable=TEST desc='Test mode' value=yes
}

##############################################################################
function opt_define_trace() {
    ### Prepare a TRACE variable to "set -x" after preparation
    ### No description > not shown in help
    opt_define short=x long=trace variable=TRACE value=X
}

##############################################################################
### Usage: source $(opt_build)
##############################################################################
function opt_build() {
    local build_file=$(mktemp /tmp/optparse-XXXXXX.tmp)

    ### Add default help option
    __opt_help -h --help 'This usage help'

    ### Function usage
    cat << EOF > $build_file
function usage() {
cat << EOT
$_opt_help
usage: \$0 ${_opt_help_args_req}[options] ${_opt_help_args}

options:
$_opt_usage
$_opt_help_hint
EOT
}

### Contract long options into short options
params=
params_=
while [ \$# -ne 0 ]; do
    param="\$1"
    shift

    case "\$param" in
$_opt_cont
        -h|--help)
            usage
            exit 0;;
        *)
            if [[ "\$param" == -- ]]; then
                ### Remember extra parameters separated by --
                params_="\$@"
                break
            elif [[ "\$param" == --* ]]; then
                echo -e "Unrecognized long option: \$param"
                usage
                exit 1
            fi
            params="\$params \"\$param\"";;
    esac
done

eval set -- "\$params"

### Set default variable values
$_opt_defs

### No errors yet...
error=

### Check required parameters
for par in \${_opt_req}; do
    var=\$(echo "\$par" | cut -d: -f1)
    eval var=\\\$\$var
    if [ "\$var" ]; then
        ### Remember error
        error+="#NL#TB- Option -\$(echo "\$par" | cut -d: -f2) is required!"
    fi
done

### Process arguments with getopts
while getopts ":$_opt_args" option; do
    case \$option in
$_opt_process
        ### Remember error
        :) error+="#NL#TB- Option -\$OPTARG requires an argument!";;
        *) usage; exit 1;;
    esac
done

if [ "\$error" ]; then
    ### Errors occurred!
    echo
    echo "There where errors:\$error"
    usage
    exit 127
fi

### Shift out all args parsed by getopts
shift \$((\$OPTIND - 1))
### Apply remaining parameters and axtra parameters to $1 $2 ...
eval set -- "\$@ \$params_"
### Predefine variable containing remaining arguments
ARGS="\$@"

### Clean up after self
rm $build_file

EOF

    local -A o=( ['#NL']='\n' ['#TB']='    ' )
    for i in "${!o[@]}"; do sed -i "s/${i}/${o[$i]}/g" $build_file; done

    # Unset global variables
    unset _opt_usage
    unset _opt_process
    unset _opt_args
    unset _opt_defs
    unset _opt_cont
    unset _opt_help
    unset _opt_help_args
    unset _opt_help_hint

    # Return file name to parent
    echo "$build_file"
}
