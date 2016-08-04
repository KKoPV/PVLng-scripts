#!/bin/bash

APIURL=https://api.twitter.com/1.1/statuses/user_timeline.json

#opts='-v'

pwd=$(dirname $0)

$pwd/contrib/curlicue $opts -f $pwd/.consumer -- -sS $APIURL
