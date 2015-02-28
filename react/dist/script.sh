#!/bin/bash
##############################################################################
### @author      Knut Kohl <github@knutkohl.de>
### @copyright   2012-2015 Knut Kohl
### @license     MIT License (MIT) http://opensource.org/licenses/MIT
### @version     1.0.0
##############################################################################

### 2 Script parameters
timestamp=$1
value=$2

datetime=$(date -d @$1 +'%x %X')

##############################################################################
### If you have a locale with NOT a dot as decimal separator and want to make
### calculations or use printf, you have to set at least LC_NUMERIC like this
LC_NUMERIC=C

cat <<EOT

    # of parameters = $#
    Timestamp       = $1 ($datetime)
    Reading value   = $2
EOT
