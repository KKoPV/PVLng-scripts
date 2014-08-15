##############################################################################
### @author      Knut Kohl <github@knutkohl.de>
### @copyright   2012-2014 Knut Kohl
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

### Helper function to fetch value from result containing one row
function _twitter_fetch_value {
    echo $(PVLngGET "$1" | cut -f2)
}

##############################################################################
twitter_last_help='Actual/last value'
### $1 - GUID
##############################################################################
function twitter_last {
    _twitter_fetch_value "data/$1.tsv?period=last"
}

##############################################################################
twitter_last_meter_help='Actual/last value of meter with start'
### $1 - Start time
### $2 - GUID
### Example params: midnight | first%20day%20of%20this%20month
### Start at today midnight  | 1st of this month
##############################################################################
function twitter_last_meter {
    _twitter_fetch_value "data/$2.tsv?start=$1&period=last"
}

##############################################################################
twitter_readlast_help='Generic item to read last value'
### $1 - GUID
##############################################################################
function twitter_readlast {
    _twitter_fetch_value "data/$1.tsv?period=readlast"
}

##############################################################################
twitter_overall_help='Overall production in MWh'
##############################################################################
function twitter_overall {
    _twitter_fetch_value "data/$1.tsv?period=readlast"
}

##############################################################################
twitter_average_help='Average value since $1'
### $1 - Start time
### $2 - GUID
### Example params: midnight
##############################################################################
function twitter_average {
    _twitter_fetch_value "data/$2.tsv?start=$1&period=99y"
}

##############################################################################
twitter_maximum_help='Maximum value since $1'
### $1 - Start time
### $2 - GUID
### Example params: midnight | first%20day%20of%20this%20month
### Start at today midnight  | 1st of this month
##############################################################################
function twitter_maximum {
    ### Get all data rows and loop to find max. value
    PVLngGET "data/$2.tsv?start=$1" | \
    awk 'NR==1 { max=$2 } { if ($2>max) max=$2 } END { print max }'
}

##############################################################################
twitter_today_working_hours_help='Today working hours in hours :-)'
##############################################################################
function twitter_today_working_hours {
    ### Get all data rows
    PVLngGET "data/$1.tsv" >$TMPFILE

    ### Get first line, get 1st value
    local min=$(cat $TMPFILE | head -n1 | cut -f1)
    ### Get last line, get 1st value
    local max=$(cat $TMPFILE | tail -n1 | cut -f1)
    log 1 "Min - Max: $min - $max"

    ### to hours
    echo "scale=4; ($max - $min) / 3600" | bc -l
}
