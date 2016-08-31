##############################################################################
### @author      Knut Kohl <github@knutkohl.de>
### @copyright   2012-2016 Knut Kohl
### @license     MIT License (MIT) http://opensource.org/licenses/MIT
### @version     1.0.0
##############################################################################

var1req DIR $i Directory

var1 PREFIX $i

var1 TEXT $i '{NAME_DESCRIPTION}: {VALUE} {UNIT}'
TEXT=$(replace_vars "$TEXT" $j)
lkv 1 TEXT "$TEXT"

[ "$TEST" ] || echo -n "$TEXT" >$(mktemp --tmpdir="$DIR" ${PREFIX:-alert}.XXXXXX)
