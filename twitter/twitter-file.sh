#!/bin/bash
##############################################################################
### @author      Knut Kohl <github@knutkohl.de>
### @copyright   2012-2013 Knut Kohl
### @license     GNU General Public License http://www.gnu.org/licenses/gpl.txt
### @version     $Id$
##############################################################################

APIURL='https://api.twitter.com/1.1/statuses/update.json'

##############################################################################
### Init
##############################################################################
pwd=$(dirname $0)

. $pwd/../PVLng.sh

[ -f $pwd/.consumer ] || error_exit "Missing token file! Did you run setup.sh?"

### Script options
opt_help      "Post status from file content to twitter"
opt_help_args "<config file>"
opt_help_hint "See twitter-file.conf.dist for details."

### PVLng default options
opt_define_pvlng

. $(opt_build)

read_config "$1"

##############################################################################
### Start
##############################################################################
PATTERN_N=$(int "$PATTERN_N")
[ $PATTERN_N -gt 0 ] || error_exit 'No file patterns defined ($PATTERN_N)'

##############################################################################
### Go
##############################################################################
[ "$TRACE" ] && set -x
[ $VERBOSE -gt 0 ] && opts="-v"

i=0

while [ $i -lt $PATTERN_N ]; do

    i=$((i+1))

    sec 1 $i

    var1 PATTERN $i
    lkv 1 Pattern "$PATTERN"

    files="$(ls $PATTERN 2>/dev/null)"

    if [ -z "$files" ]; then
        log 1 "No files."
        continue
    fi

    for file in $files; do

        sec 1 $file

        ### Trim status
        STATUS=$(cat $file | sed -e 's~^ ~~' -e 's~ $~~')

        lkv 1 Status "$STATUS"
        lkv 1 Length $(echo $STATUS | wc -c)

        [ "$STATUS" ] || continue
        [ "$TEST" ] && continue

        printf -v STATUS "$(echo "$STATUS" | sed -e 's/ *|| */\\n/g')"
        STATUSENC=$(urlencode "$STATUS")

        ### Put all data into one -d for curlicue
        $pwd/contrib/curlicue -f $pwd/.consumer $opts -- \
            -sS -d status="$STATUSENC&lat=$LAT&long=$LONG" "$APIURL" >$TMPFILE

        ### Ignore {"errors":[{"code":187,"message":"Status is a duplicate."}]}
        if grep 'errors' $TMPFILE | grep -qv '"code":187'; then
            echo "Status: $STATUS"
            echo
            cat $TMPFILE
            echo
        fi

        eval move="\$FILE_${i}_MOVE"

        if [ "$move" ]; then
            [ -d "$move" ] || mkdir -p "$move"
            mv "$file" "$move" 2>/dev/null
        else
            rm "$file"
        fi
    done

done
