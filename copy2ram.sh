#!/bin/sh

#set -x

pwd=$(readlink -f $(dirname $0))
tmp=${1:-$(dirname $(mktemp -u))}

rsync -a "$pwd" "$tmp" --exclude .git --exclude data

[ $? -eq 0 ] || exit

echo
echo "Put this to your crontab:"
echo "    @reboot $pwd/$(basename $0) $tmp"
echo
echo "Run your scripts in crontab like this"
echo "    bash $tmp/<directory>/<script> ..."
echo
