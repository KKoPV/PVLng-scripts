##############################################################################
### @author      Knut Kohl <github@knutkohl.de>
### @copyright   2012-2016 Knut Kohl
### @license     MIT License (MIT) http://opensource.org/licenses/MIT
### @version     1.2.0
###
### 1.0.0
### Initial creation, copy from twitter
##############################################################################

### Used by item functions for buffering
temp_file ITEMTMPFILE

##############################################################################
### Helper function to fetch value from result containing one row
### $1 GUID
### $2 URL parameters
### Return value only, no timestamp
##############################################################################
function _telegram_fetch_value {
    PVLngGET "data/$1.tsv?$2" | cut -f2-
}

##############################################################################
telegram_last_help='Actual/last value'
### $1 - GUID
##############################################################################
function telegram_last {
    _telegram_fetch_value $1 "period=last"
}

##############################################################################
telegram_last_meter_help='Actual/last value of meter since $1, default "midnight"'
### $1 - Start time; optional, default "midnight"
### $2 - GUID
### Example params: midnight | first%20day%20of%20this%20month
### Start at today midnight  | 1st of this month
##############################################################################
function telegram_last_meter {
    local start=$1
    local GUID=$2
    if [ $# -eq 1 ]; then
        ### Missing start, inject "midnight"
        start=midnight
        GUID=$1
    fi
    _telegram_fetch_value $GUID "start=${start}&period=last"
}

##############################################################################
telegram_readlast_help='Generic item to read last value'
### $1 - GUID
##############################################################################
function telegram_readlast {
    _telegram_fetch_value $1 "period=readlast"
}

##############################################################################
telegram_overall_help='Overall production in MWh'
### $1 - GUID
##############################################################################
function telegram_overall {
    _telegram_fetch_value $1 "period=readlast"
}

##############################################################################
telegram_average_help='Average value since $1, default "midnight"'
### $1 - Start time; optional, default "midnight"
### $2 - GUID
### Example params: midnight
##############################################################################
function telegram_average {
    local start=$1
    local GUID=$2
    if [ $# -eq 1 ]; then
        ### Missing start, inject "midnight"
        start=midnight
        GUID=$1
    fi
    _telegram_fetch_value $GUID "start=${start}&period=99y"
}

##############################################################################
telegram_maximum_help='Maximum value since $1, default "midnight"'
### $1 - Start time; optional, default "midnight"
### $2 - GUID
### Example params: midnight | first%20day%20of%20this%20month
### Start at today midnight  | 1st of this month
##############################################################################
function telegram_maximum {
    local start=$1
    local GUID=$2
    if [ $# -eq 1 ]; then
        ### Missing start, inject "midnight"
        start=midnight
        GUID=$1
    fi
    ### Get all data rows and loop to find max. value
    PVLngGET "data/$GUID.tsv?start=$start" | \
    awk 'NR==1 { max=$2 } { if ($2>max) max=$2 } END { print max }'
}

##############################################################################
telegram_today_working_hours_help='Today working hours in hours'
##############################################################################
function telegram_today_working_hours {
    ### Get all data rows
    PVLngGET "data/$1.tsv" >$ITEMTMPFILE

    ### Get first line, get 1st value
    local min=$(head -n1 $ITEMTMPFILE | cut -f1)
    ### Get last line, get 1st value
    local max=$(tail -n1 $ITEMTMPFILE | cut -f1)
    lkv 1 "Min - Max" "$(date -d @$min +%X) - $(date -d @$max +%X)"

    ### to hours
    calc "($max - $min) / 3600"
}

##############################################################################
telegram_today_working_hours_minutes_help='Today working hours in hh:mm'
##############################################################################
function telegram_today_working_hours_minutes {
    local hours=$(telegram_today_working_hours $1)
    local h=$(calc "$hours" 0)
    local m=$(calc "$hours * 60 - $h * 60" 0)

    ### Fix rounding issue, minutes will be negative, correct hours and minutes
    if [ $m -lt 0 ]; then
        h=$((h-1))
        m=$((60+m))
    fi
    printf "%02d:%02d" $h $m
}

