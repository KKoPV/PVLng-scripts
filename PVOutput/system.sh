#!/bin/sh
##############################################################################
### @author      Knut Kohl <github@knutkohl.de>
### @copyright   2012-2014 Knut Kohl
### @license     MIT License (MIT) http://opensource.org/licenses/MIT
### @version     1.0.0
##############################################################################

##############################################################################
### Init
##############################################################################

source $(dirname $0)/../PVLng.sh

### Script options
opt_help      "Update a system on PVOutput.org"
opt_help_args "<config file>"
opt_help_hint "See pvoutput.conf.dist and system.conf.dist for details."

### PVLng default options with flag for save data
opt_define_pvlng

source $(opt_build)

CONFIG="$1"

read_config "$CONFIG"
read_config $(dirname $0)/pvoutput.conf

##############################################################################
### Start
##############################################################################
test "$TRACE" && set -x

test "$APIKEY"	 || error_exit "pvoutput.org API key is required, see pvoutput.conf.dist"
test "$SYSTEMID" || error_exit "pvoutput.org Plant Id is required"

curl="$(curl_cmd)"

### Get system status interval
ifile=$(run_file PVOutput "$CONFIG" interval)

if test -f "$ifile"; then
	INTERVAL=$(<$ifile)
else
	log 1 "Fetch System infos..."
	### Extract status interval from response, 16th value
	### http://pvoutput.org/help.html#api-getsystem
	INTERVAL=$($curl --header "X-Pvoutput-Apikey: $APIKEY" \
                     --header "X-Pvoutput-SystemId: $SYSTEMID" \
                     $GetSystemURL | cut -d';' -f1 | cut -d',' -f16)
	### Store valid status interval or set to maximum status interval until next run
	test $(int "$INTERVAL") -ne 0 && echo $INTERVAL >$ifile || INTERVAL=15
fi

DATA=
i=0
check=

while test $i -lt $vMax; do

	i=$((i + 1))

	log 1 "--- v$i ---"

	eval GUID=\$GUID_$i

	if test "$GUID"; then
	
		log 1 "$(printf 'GUID    %2d: %s' $i $GUID)"

		eval FACTOR=\$FACTOR_$i
		test "$FACTOR" || FACTOR=1
		log 1 "$(printf 'FACTOR  %2d: %s' $i $FACTOR)"

		### empty temp. file
		echo -n >$TMPFILE

		value=$(PVLngGET data/$GUID.tsv?period=${INTERVAL}minute | tail -n1 | cut -f2)

		### unset only zero values for v1 .. v4
		if test $i -le 4; then
			test "$value" = "0" && value=
		fi

		if test "$value"; then
			value=$(calc "$value * $FACTOR")
			DATA="$DATA -d v$i=$value"
		fi
		log 1 "$(printf 'VALUE   %2d: %s' $i $value)"

		check="$check$value"
	fi

	### Check if at least one of v1...v4 is set
	if test $i -eq 4; then
		if test "$check"; then
			log 1 "OK        : At least one of v1 .. v4 is filled ..."
		else
			### skip further processing
			log 1 "SKIP      : All of v1 .. v4 are empty!"
			exit
		fi
	fi

done

DATA="-d d="$(date "+%Y%m%d")" -d t="$(date "+%H:%M")"$DATA"

log 1 "Data      : $DATA"

test -z "$TEST" || exit

#save_log "PVOutput" "$DATA"

### Send
$curl --header "X-Pvoutput-Apikey: $APIKEY" \
      --header "X-Pvoutput-SystemId: $SYSTEMID" \
      --output $TMPFILE $DATA $AddStatusURL
rc=$?

log 1 $(cat $TMPFILE)

### Check curl exit code
if test $rc -ne 0; then
	. $pwd/../curl-errors
	save_log "PVOutput" "Curl error ($rc): ${curl_rc[$rc]}"
fi

### Check result, ONLY 200 is ok
if cat $TMPFILE | grep -q '200:'; then
	### Ok, state added
	log 1 "Ok"
else
	### log error
	save_log "PVOutput" "$SYSTEMID - Update failed: $(cat $TMPFILE)"
	save_log "PVOutput" "$SYSTEMID - Data: $DATA"
fi
