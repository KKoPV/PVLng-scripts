##############################################################################
### @author     Knut Kohl <github@knutkohl.de>
### @copyright  2012-2015 Knut Kohl
### @license    MIT License (MIT) http://opensource.org/licenses/MIT
### @version    1.0.0
###
### Idea from Optparse - a BASH wrapper for getopts
### @author : nk412 / nagarjuna.412@gmail.com
### Adapted to work not only with bash and extended
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
__opt_error () {
    local message="$1"
    echo "ERROR: $message"
    exit 1
}

##############################################################################
### Helper function
##############################################################################
__opt_help () {
    local short="-$1"
    local long="--$2"
    _opt_usage+="#T$(printf "%s, %-20s %s" "$short" "$long" "$3")#N"
}

##############################################################################
opt_help () {
    _opt_help=$(echo "#N$1#N" | sed 's~\n~#N~g;s~\\n~#N~g')
}

##############################################################################
opt_help_hint () {
    _opt_help_hint=$(echo "$1" | sed 's~\\n~#N~g')
}

##############################################################################
opt_help_args () {
    _opt_help_args="$1"
}

##############################################################################
opt_define () {
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
        key=$(echo "$option" | cut -d= -f1)
        value="$(echo "$option" | cut -d= -f2-)"

        ### Essentials: long, description
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
            elif [ "$default" ]; then
                ### Parameter with default value
                desc+=" [default:$default]"
            fi
        fi
        if [ "$required" ]; then
            _opt_req+=" $variable:$short"
            _opt_help_args_req+="(-${short}|--${long}) <${long}> "
            desc+=" (required)"
        fi
        __opt_help "$short" "$long" "$desc"
    fi

    _opt_cont+="#T#T--${long})#N#T#T#Tparams=\"\$params -${short}\";;#N"

    ### Initialize all variables, also empty once
    _opt_defs+="${variable}=${default}#N"

    if [ "$val" = "\$OPTARG" ]; then
        ### Option requires parameter
        _opt_args+="${short}:"
    else
        _opt_args+="${short}"
    fi

    if [ "$callback" ]; then
        _opt_process+="#T#T${short}) ${callback};;#N"
    else
        _opt_process+="#T#T${short}) ${variable}=\"$val\";;#N"
    fi
}

##############################################################################
opt_define_test () {
    opt_define short=t long=test variable=TEST value=y desc='Test mode'
}

##############################################################################
opt_define_verbose () {
    opt_define short=v long=verbose variable=VERBOSE default=0 value=0 \
               desc='Verbosity, use multiple times for higher level' \
               callback='VERBOSE=$(($VERBOSE+1))'
}

##############################################################################
opt_define_quiet () {
    opt_define short=q long=quiet variable=QUIET value=1 \
               desc='Quiet mode, no output' callback='VERBOSE=-1'
}

##############################################################################
opt_define_trace () {
    ### Prepare a TRACE variable to "set -x" after preparation
    ### No description, not shown in help
    opt_define short=x long=trace variable=TRACE value=y
}

##############################################################################
### Usage: source $(opt_build)
##############################################################################
opt_build () {
    local build_file=$(mktemp)

    ### Add default help option
    __opt_help h help 'This usage help'

    ### Function usage
    cat << EOF > $build_file
usage () {
[ "\$1" ] && echo && echo \$1
cat << EOT
$_opt_help
usage: \$0 ${_opt_help_args_req}[options] ${_opt_help_args}

options:
$_opt_usage
$_opt_help_hint

EOT
[ "\$2" ] && exit \$2
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
            rm $build_file
            exit 0;;
        *)
            if [[ "\$param" == -- ]]; then
                ### Remember extra parameters separated by --
                params_="\$@"
                break
            elif [[ "\$param" == --* ]]; then
                echo -e "Unrecognized long option: \$param"
                usage
                rm $build_file
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
        error+="#N- Option -\$(echo "\$par" | cut -d: -f2) is required!"
    fi
done

### Process arguments with getopts
while getopts ":$_opt_args" option; do
    case \$option in
$_opt_process
        ### Remember error
        :) error+="#N- Option -\$OPTARG requires an argument!";;
        *) error+="#N- Unknown option: -\$OPTARG";;
    esac
done

if [ "\$error" ]; then
    ### Errors occurred!
    echo
    echo "\$error"
    usage
    rm $build_file
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

[ "\$TEST" ] && log 1 Test mode

EOF

    ### Replace #N with new lines and #T with 4 spaces
    sed -i "s/#N/\n/g" $build_file
    sed -i "s/#T/    /g" $build_file

    ### Unset global variables
    unset _opt_usage
    unset _opt_process
    unset _opt_args
    unset _opt_defs
    unset _opt_cont
    unset _opt_help
    unset _opt_help_args
    unset _opt_help_hint

    ### Return file name to parent
    echo "$build_file"
}
