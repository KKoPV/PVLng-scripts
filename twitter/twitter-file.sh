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
### Init
##############################################################################
. $pwd/../PVLng.sh

[ -f $pwd/.consumer ] || error_exit "Missing token file! Did you run setup.sh?"

### Script options
opt_help      "Post status from file content to twitter"
opt_help_args "(-p|--pattern|<config file>)"
opt_help_hint "See twitter-file.conf.dist for details."

opt_define short=p long=pattern desc="File pattern to search for, no config file required" variable=PATTERN

### PVLng default options
opt_define_pvlng

. $(opt_build)

CONFIG=$1

if [ "$PATTERN" ]; then
    PATTERN_N=1
    PATTERN_1=$PATTERN
    read_config twitter-file.conf
    check_required USER 'Twitter account'
    check_required PASS 'Twittter password'
else
    read_config "$CONFIG"
fi

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

PATTERN_N=$(int "$PATTERN_N")
[ $PATTERN_N -gt 0 ] || exit_required 'File patterns' PATTERN_N

##############################################################################
### Go
##############################################################################
[ $VERBOSE -gt 0 ] && opts="-v"

i=0

while [ $i -lt $PATTERN_N ]; do

    i=$((i+1))

    sec 1 $i

    var1 PATTERN $i

    ls $PATTERN 2>/dev/null | while read file; do
        sec 1 "$file"
        ### Trim status
        sed -i 's~^ *~~g;s~ *$~~g' "$file"

        [ ! -s "$file" ] && rm $file && continue

        log 1 @$file Status
        lkv 1 Length $(wc -c "$file")

        [ "$TEST" ] && continue

        printf -v STATUS "$(sed 's~ *|| *~\\n~g' "$file")"

        $BINDIR/tweet.sh "$USER" "$PASS" "$STATUS" >$TMPFILE

        if [ $? -ne 0 ]; then
            log 0 @$TMPFILE
            continue
        fi

        var1 MOVEDIR $i

        if [ "$MOVEDIR" ]; then
            [ -d "$MOVEDIR" ] || mkdir -p "$MOVEDIR"
            mv "$file" "$MOVEDIR" 2>/dev/null
        else
            rm "$file"
        fi
    done

done

exit 0
