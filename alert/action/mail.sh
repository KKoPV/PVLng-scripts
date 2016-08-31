##############################################################################
### @author      Knut Kohl <github@knutkohl.de>
### @copyright   2012-2016 Knut Kohl
### @license     MIT License (MIT) http://opensource.org/licenses/MIT
### @version     1.0.0
##############################################################################

var1req EMAIL $i Email

var1 SUBJECT $i '[PVLng] {NAME_DESCRIPTION}: {VALUE} {UNIT}'
var1 BODY $i

sendMail "$(replace_vars "$SUBJECT" $j)" "$(replace_vars "$BODY" $j)" $EMAIL
