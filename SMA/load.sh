#!/bin/bash
##############################################################################
### @author      Knut Kohl <github@knutkohl.de>
### @copyright   2012-2015 Knut Kohl
### @license     MIT License (MIT) http://opensource.org/licenses/MIT
### @version     1.0.0
##############################################################################

##############################################################################
### Init
##############################################################################
pwd=$(dirname $0)

. $pwd/../PVLng.sh

### Script options
opt_help      "Load saved or failed Inverter or Sensorbox data for SMA Webbox"
opt_help_args "<GUID> <directory>"

opt_define short=d long=delete desc='Delete processed files' variable=DELETE value=y

### PVLng default options
opt_define_pvlng

. $(opt_build)

##############################################################################
### Start
##############################################################################
if [ $# -lt 2 ]; then
    usage
    exit 1
fi

##############################################################################
### Let's go
##############################################################################
[ "$TRACE" ] && set -x

curl=$(curl_cmd)

find $2 -type f 2>/dev/null | sort | while read file; do

    log 0 Process $(basename $file) ...

    [ "$TEST" ] && continue

    ### Clear temp. file before
    >$TMPFILE

    rc=$($curl --request PUT \
               --header "X-PVLng-key: $PVLngAPIkey" \
               --write-out %{http_code} \
               --output $TMPFILE \
               --data-binary "@$file" \
               $PVLngURL/data/$1.txt)

    if echo "$rc" | grep -qe '^20[012]'; then
        ### 200/201/202 Ok
        msg="> Ok [$rc] $(<$TMPFILE)"
        if [ "$DELETE" ]; then
            rm "$file" && msg="$msg - file deleted"
            ### Delete both levels (year-month/day) below GUID
            find $(dirname $file) -type d -empty -delete
            find $(dirname $(dirname $file)) -type d -empty -delete
        fi

        log 0 "$msg"
    else
        ### Any other is an error
        error_exit "Failed [$rc] $(<$TMPFILE)"
    fi

done
