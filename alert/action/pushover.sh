##############################################################################
### @author      Knut Kohl <github@knutkohl.de>
### @copyright   2012-2016 Knut Kohl
### @license     MIT License (MIT) http://opensource.org/licenses/MIT
### @version     1.0.0
##############################################################################

var1req USER  $i User
var1req TOKEN $i Token

var1 DEVICE $i

var1 TITLE $i
TITLE=$(replace_vars "$TITLE" $j)
lkv 1 TITLE "$TITLE"

var1 TEXT $i '{NAME_DESCRIPTION}: {VALUE} {UNIT}'
TEXT=$(replace_vars "$TEXT" $j)
lkv 1 TEXT "$TEXT"

var1 PRIORITY $i 0
var1 SOUND $i

[ "$SOUND" ] && SOUND="-s $SOUND"

if [ -z "$TEST" ]; then
    res=$($pwd/../bin/pushover.sh -u "$USER" -a "$TOKEN" -d "$DEVICE" -t "$TITLE" -m "$TEXT" -p $PRIORITY $SOUND)
    lkv 1 Response "$res"
fi
