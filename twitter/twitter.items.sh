##############################################################################
### @author      Knut Kohl <github@knutkohl.de>
### @copyright   2012-2015 Knut Kohl
### @license     MIT License (MIT) http://opensource.org/licenses/MIT
### @version     1.2.0
###
### 1.2.0
### Wrapper func. to fetch value from one-liner result
### Max. calculation with awk
###
### 1.1.0
### Adjust functions, make more variable
###
### 1.0.0
### Initial creation
##############################################################################

##############################################################################
### Helper function to fetch value from result containing one row
### $1 GUID
### $2 URL parameters
### Return value only, no timestamp
##############################################################################
function _twitter_fetch_value {
    PVLngGET "data/$1.tsv?$2" | cut -f2-
}

##############################################################################
twitter_last_help='Actual/last value'
### $1 - GUID
##############################################################################
function twitter_last {
    _twitter_fetch_value $1 "period=last"
}

##############################################################################
twitter_last_meter_help='Actual/last value of meter since $1, default "midnight"'
### $1 - Start time; optional, default "midnight"
### $2 - GUID
### Example params: midnight | first%20day%20of%20this%20month
### Start at today midnight  | 1st of this month
##############################################################################
function twitter_last_meter {
    local start=$1
    local GUID=$2
    if [ $# -eq 1 ]; then
        ### Missing start, inject "midnight"
        start=midnight
        GUID=$1
    fi
    _twitter_fetch_value $GUID "start=${start}&period=last"
}

##############################################################################
twitter_readlast_help='Generic item to read last value'
### $1 - GUID
##############################################################################
function twitter_readlast {
    _twitter_fetch_value $1 "period=readlast"
}

##############################################################################
twitter_overall_help='Overall production in MWh'
### $1 - GUID
##############################################################################
function twitter_overall {
    _twitter_fetch_value $1 "period=readlast"
}

##############################################################################
twitter_average_help='Average value since $1, default "midnight"'
### $1 - Start time; optional, default "midnight"
### $2 - GUID
### Example params: midnight
##############################################################################
function twitter_average {
    local start=$1
    local GUID=$2
    if [ $# -eq 1 ]; then
        ### Missing start, inject "midnight"
        start=midnight
        GUID=$1
    fi
    _twitter_fetch_value $GUID "start=${start}&period=99y"
}

##############################################################################
twitter_maximum_help='Maximum value since $1, default "midnight"'
### $1 - Start time; optional, default "midnight"
### $2 - GUID
### Example params: midnight | first%20day%20of%20this%20month
### Start at today midnight  | 1st of this month
##############################################################################
function twitter_maximum {
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
twitter_today_working_hours_help='Today working hours in hours :-)'
##############################################################################
function twitter_today_working_hours {
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
twitter_today_working_hours_help='Today working hours in hh:mm'
##############################################################################
function twitter_today_working_hours_minutes {
    local hours=$(twitter_today_working_hours $1)
    local h=$(calc "$hours" 0)
    local m=$(calc "$hours * 60 - $h * 60" 0)

    ### Fix rounding issue, minutes will be negative, correct hours and minutes
    if [ $m -lt 0 ]; then
        h=$((h-1))
        m=$((60+m))
    fi
    printf "%d:%02d" $h $m
}

