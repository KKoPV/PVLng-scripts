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
pwd=$(dirname $0)

. $pwd/../PVLng.sh

### Script options
opt_help      "Get last reading of a single channel.
Can be logged to file for e.g. for solar estimate over day"
opt_help_args "<config file>"
opt_help_hint "See watch.conf.dist for details."

opt_define short=v long=verbose variable=VERBOSE \
           desc='Verbosity, use multiple times for higher level' \
           default=0 value=1 callback='VERBOSE=$(($VERBOSE+1))'
opt_define short=x long=trace variable=TRACE value=y

. $(opt_build)

read_config "$1"

##############################################################################
### Start
##############################################################################
test "$GUID" || error_exit "No GUID defined (GUID)"
test "$FORMAT" || ( FORMAT="%s": log 1 "Set FORMAT to '%s'" )

##############################################################################
### Go
##############################################################################
[ "$TRACE" ] && set -x

data=$(PVLngGET "data/$GUID.tsv?period=readlast")

[ "$data" ] && set $data && printf "%s;$FORMAT\n" "$(date +'%Y-%m-%d %H:%M;%s')" "$2"
