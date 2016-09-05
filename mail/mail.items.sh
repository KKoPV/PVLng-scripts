##############################################################################
### @author      Knut Kohl <github@knutkohl.de>
### @copyright   2012-2016 Knut Kohl
### @license     MIT License (MIT) http://opensource.org/licenses/MIT
### @version     1.0.0
###
### 1.0.0
### - Initial creation
##############################################################################

##############################################################################
### Helper function to fetch value from result containing one row
### $1 GUID
### $2 URL parameters
### Return value only, no timestamp
##############################################################################
function _mail_fetch {
    local params=$(echo ${2} | sed 's/  */+/g')
    ### Fetch TAB separated for cut
    PVLngGET "data/$1.tsv?$params" | cut -f2-
}

##############################################################################
### $1 - GUID
##############################################################################
function mail_last {
    _mail_fetch $1 "period=last"
}

##############################################################################
### $1 - GUID
##############################################################################
function mail_last_meter {
    var1 START $i midnight
    var1 END   $i "next day midnight"
    _mail_fetch $1 "start=$START&end=$END&period=last"
}

##############################################################################
### $1 - GUID
##############################################################################
function mail_readlast {
    _mail_fetch $1 "period=readlast"
}

##############################################################################
### $1 - GUID
##############################################################################
function mail_overall {
    _mail_fetch $1 "period=readlast"
}

##############################################################################
### $1 - GUID
##############################################################################
function mail_average {
    var1 START $i midnight
    var1 END   $i "next day midnight"
    _mail_fetch $1 "start=$START&end=$END&period=99y"
}

##############################################################################
### $1 - GUID
##############################################################################
function mail_maximum {
    var1 START $i midnight
    START=$(echo $START | sed 's/  */+/g')
    var1 END $i "next day midnight"
    END=$(echo $END | sed 's/  */+/g')
    ### Get all data rows and loop to find max. value
    PVLngGET "data/$1.tsv?start=$START&end=$END" | \
    awk 'NR==1 {max=$2} {if ($2>max) max=$2} END {print max}'
}

##############################################################################
### $1 - GUID
##############################################################################
function mail_today_working_hours {
    ### Get all data rows
    PVLngGET "data/$1.tsv" >$TMPFILE

    ### Get 1st lines value
    local min=$(head -n1 $TMPFILE | cut -f1)
    ### Get last lines value
    local max=$(tail -n1 $TMPFILE | cut -f1)
    lkv 1 "Min - Max" "$(date -d @$min +%X) - $(date -d @$max +%X)"

    ### to hours
    calc "($max - $min) / 3600"
}

##############################################################################
### $1 - GUID
##############################################################################
function mail_today_working_hours_minutes {
    local hours=$(mail_today_working_hours $1)
    local h=$(calc "$hours" 0)
    local m=$(calc "$hours * 60 - $h * 60" 0)

    ### Fix rounding issue, minutes will be negative, correct hours and minutes
    if [ $m -lt 0 ]; then
        h=$((h-1))
        m=$((60+m))
    fi
    printf "%02d:%02d" $h $m
}


##############################################################################
### Last 7 days
### $1 - GUID
##############################################################################
function mail_week {
    local start='-1 week midnight'
    _mail_fetch $1 "start=$start&period=last"
}

##############################################################################
### This month up to now
### $1 - GUID
##############################################################################
function mail_month {
    local start='first day of this month midnight'
    _mail_fetch $1 "start=$start&period=last"
}

##############################################################################
### Last month
### $1 - GUID
##############################################################################
function mail_last_month {
    local start='first day of last month midnight'
    local end='first day of this month midnight'
    _mail_fetch $1 "start=$start&end=$end&period=last"
}

##############################################################################
### This year up to now
### $1 - GUID
##############################################################################
function mail_year {
    local start='first day of january midnight'
    _mail_fetch $1 "start=$start&period=last"
}

##############################################################################
### Last year
### $1 - GUID
##############################################################################
function mail_last_year {
    local start='first day of january midnight -1year'
    local end='first day of january midnight'
    _mail_fetch $1 "start=$start&end=$end&period=last"
}
