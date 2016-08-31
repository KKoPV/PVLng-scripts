##############################################################################
### @author      Knut Kohl <github@knutkohl.de>
### @copyright   2012-2016 Knut Kohl
### @license     MIT License (MIT) http://opensource.org/licenses/MIT
### @version     1.0.0
##############################################################################

var1req TOKEN $i 'Telegram token'
var1req CHAT  $i 'Telegram chat Id'

var1 TEXT $i '{NAME_DESCRIPTION}: {VALUE} {UNIT}'
TEXT=$(replace_vars "$TEXT" $j)
lkv 1 TEXT "$TEXT"

[ "$TEST" ] || lkv 1 Response $($pwd/../bin/telegram.sh $TOKEN $CHAT "$TEXT" >/dev/null 2>&1)
