#!/bin/bash
##############################################################################
### You can pause all scripts by creating a file .paused
###
### Run this script
###     ./pause.sh
### to toggle status or
###     ./pause.sh (on|off)
### to force special state
###
### @author      Knut Kohl <github@knutkohl.de>
### @copyright   2012-2015 Knut Kohl
### @license     MIT License (MIT) http://opensource.org/licenses/MIT
### @version     1.0.0
##############################################################################

mode=$1

file=$(dirname $0)/.paused

if [ ! "$mode" -a ! -f $file ]; then
    mode=on
fi

echo "Switch pause mode ${mode:-off}"

if [ "$mode" == on ]; then
    touch $file
else
    rm $file >/dev/null 2>&1
fi
