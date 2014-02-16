#! /bin/sh

if test $# -ne 6; then
	echo "Usage: $0 <Actor> <Actual> <Threshold> <Period> <OnScript> <OffScript>"
	exit 1
fi

NAME="$1"
ACTUAL=$2
THRESHOLD=$3
PERIOD=$4
SCRIPTON="$5"
SCRIPTOFF="$6"

runfile="/var/run/actor.$NAME.run"

now=$(date +"%s")

if $ACTUAL -ge $THRESHOLD; then
	test -f $runfile || source $SCRIPTON
	expr $now + $PERIOD >$runfile
elif test -f $runfile; then
	test $(<$runfile) -lt $now && source $SCRIPTOFF && rm -f $runfile
fi
