#!/bin/sh

#set -x

pwd=$(readlink -f $(dirname $0))

[ -z "$1" ] && printf "\nUsage: $0 <temp. dir>\n\n" && exit 1

rsync -a "$pwd" "$1" --exclude .git --exclude data

echo
echo "Put this to your crontab:"
echo "    @reboot $pwd/$(basename $0) $1"
echo "Run your scripts in crontab with this base dir:"
echo "    $pwd"
echo
