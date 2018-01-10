#!/bin/bash
# Twitter status update bot
# Author: Luka Pusic <luka@pusic.com>
# https://github.com/lukapusic/twitter-bot

# REQUIRED PARAMS (Special characters must be urlencoded.)
username=$1
password=$2
shift; shift

tweet="$*" # tweet length must be less than 140 chars

# EXTRA OPTIONS
uagent="Mozilla/5.0 (Series40; NokiaX2-02/10.90; Profile/MIDP-2.1 Configuration/CLDC-1.1) Gecko/20100401 S40OviBrowser/1.0.2.26.11"
sleeptime=0 # seconds between requests

if [ $(echo "$tweet" | wc -c) -gt 140 ]; then
	echo "[FAIL] Tweet must not be longer than 140 chars!" && exit 1
elif [ "$tweet" == "" ]; then
	echo "[FAIL] Nothing to tweet. Enter your text as argument." && exit 1
fi

cookie=/tmp/twitter.cookie

if [ ! -s $cookie ]; then
    # GRAB LOGIN TOKENS
    echo "[+] Fetching twitter.com..." && sleep $sleeptime
    initpage=$(curl -s -b $cookie -c $cookie -L -A "$uagent" "https://mobile.twitter.com/session/new")
    token=$(echo "$initpage" | grep "authenticity_token" | sed -e 's/.*value="//' | cut -d '"' -f 1 | head -n 1)

    # LOGIN
    echo "[+] Submitting the login form..." && sleep $sleeptime
    loginpage=$(curl -s -b $cookie -c $cookie -L -A "$uagent" -d "authenticity_token=$token&session[username_or_email]=$username&session[password]=$password&remember_me=1&wfa=1&commit=Log+in" "https://mobile.twitter.com/sessions")

    # CHECK IF LOGIN FAILED
    [[ "$loginpage" == *"/account/begin_password_reset"* ]] && { echo "[!] Login failed. Exiting."; exit 1; }
    [[ "$loginpage" == *"/account/login_challenge"* ]] && { echo "[!] Login challenge encountered. Exiting."; exit 1; }
    [[ "$loginpage" == *"/account/login_verification"* ]] && { echo "[!] Login verification encountered. Exiting."; exit 1; }
fi

# GRAB COMPOSE TWEET TOKENS
echo "[+] Getting compose tweet page..." && sleep $sleeptime
composepage=$(curl -s -b $cookie -c $cookie -L -A "$uagent" "https://mobile.twitter.com/compose/tweet")

# TWEET
echo "[+] Posting tweet..." && sleep $sleeptime
tweettoken=$(echo "$composepage" | grep "authenticity_token" | sed -e 's/.*value="//' | cut -d '"' -f 1 | tail -n 1)
update=$(curl -s -b $cookie -c $cookie -L -A "$uagent" -d "wfa=1&authenticity_token=$tweettoken&tweet[text]=$tweet&commit=Tweet" "https://mobile.twitter.com/compose/tweet")

# DON'T LOGOUT

exit 0

# GRAB LOGOUT TOKENS
logoutpage=$(curl -s -b $cookie -c $cookie -L -A "$uagent" "https://mobile.twitter.com/account")

# LOGOUT
echo "[+] Logging out..." && sleep $sleeptime
logouttoken=$(echo "$logoutpage" | grep "authenticity_token" | sed -e 's/.*value="//' | cut -d '"' -f 1 | tail -n 1)
logout=$(curl -s -b $cookie -c $cookie -L -A "$uagent" -d "authenticity_token=$logouttoken" "https://mobile.twitter.com/session/destroy")
