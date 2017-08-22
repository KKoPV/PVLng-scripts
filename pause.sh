#!/bin/bash
##############################################################################
### @author      Knut Kohl <github@knutkohl.de>
### @copyright   2012-2017 Knut Kohl
### @license     MIT License (MIT) http://opensource.org/licenses/MIT
###
### You can pause all scripts by creating a file .paused
###
### Run this script to toggle status
###     ./pause.sh
### or to force special state
###     ./pause.sh (on|off)
###
##############################################################################

mode=$1

file=$(dirname $0)/.paused

if [ -z "$mode" -a ! -f $file ]; then
    mode=on
fi

echo "Switch pause mode ${mode:-off}"

if [ "$mode" == on ]; then
    touch $file
else
    rm $file >/dev/null 2>&1
fi
