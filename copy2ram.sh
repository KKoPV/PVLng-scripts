#!/bin/sh

#set -x

pwd=$(readlink -f $(dirname $0))
tmp=$1

[ -z "$tmp" ] && printf "\nUsage: $0 <temp. dir>\n\n" && exit 1

rsync -a "$pwd" "$tmp" --exclude .git --exclude data

echo
echo "Put this to your crontab:"
echo "    @reboot $pwd/$(basename $0) $tmp"
echo
echo "Run your scripts in crontab with this base dir:"
echo "    $tmp/"
echo
