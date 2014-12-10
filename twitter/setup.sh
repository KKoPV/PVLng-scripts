#!/bin/sh
##############################################################################
### @author      Knut Kohl <github@knutkohl.de>
### @copyright   2012-2014 Knut Kohl
### @license     MIT License (MIT) http://opensource.org/licenses/MIT
### @version     1.1.0
##############################################################################
pwd=$(dirname $0)

### PVLng application credentials
CONSUMER_KEY='4Qs7FkTWVyJKfZKYSadAw'
CONSUMER_SECRET='baUNgkJxIbSiPau7VXBq1I1h4byWDNHRuqq2vmGA'

### Twitter URLs
request_token_url='https://api.twitter.com/oauth/request_token'
authorize_url='https://api.twitter.com/oauth/authorize?oauth_token=$oauth_token'
access_token_url='https://api.twitter.com/oauth/access_token'

### Temp. file names
consumer_tmp=$(mktemp consumer.XXXXXX)
request_token_tmp=$(mktemp request_token.XXXXXX)
access_token_tmp=$(mktemp access_token.XXXXXX)

trap 'rm $consumer_tmp $request_token_tmp $access_token_tmp' 0

curlicue=$pwd/contrib/curlicue

echo "oauth_consumer_key=$CONSUMER_KEY&oauth_consumer_secret=$CONSUMER_SECRET" > $consumer_tmp

echo ================================================
echo '  Setup authorization for your twitter account'
echo ================================================

echo '- Fetch PVLng application authorization token...'

$curlicue -f $consumer_tmp -p 'oauth_callback=oob' -- \
          -s -d '' "$request_token_url" > $request_token_tmp

echo '- Load this URL in your browser:'
echo '  '$($curlicue -f $consumer_tmp -f $request_token_tmp -e "$authorize_url")
read -p '- Enter the given PIN: ' pin
echo '- Authenticate and fetch user tokens...'

$curlicue -f $consumer_tmp -f $request_token_tmp ${pin:+-p "oauth_verifier=$pin"} -- \
          -s -d '' "$access_token_url" > $access_token_tmp

if grep -vq 'oauth_token=' $access_token_tmp; then
    echo
    echo "Something went wrong: $(<$access_token_tmp)"
    echo
    echo 'Please try again!'
    exit
fi

paste -d '&' $consumer_tmp $access_token_tmp >$pwd/.consumer

echo "- Tokens saved to $pwd/.consumer"
