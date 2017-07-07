#!/bin/sh

#set -x

pwd=$(readlink -f $(dirname $0))
base=$(basename $pwd)
tmp=${1:-$(dirname $(mktemp -u))}

rsync -a "$pwd" "$tmp" --exclude .git --exclude data

[ $? -eq 0 ] || exit

echo
echo "Put this to your crontab for default temp. directory:"
echo "    @reboot $pwd/$(basename $0)"
echo
echo "Put this to your crontab to use an other temp. directory:"
echo "    @reboot $pwd/$(basename $0) <directory name>"
echo
echo "Run your scripts in crontab like this"
echo "    bash $tmp/$base/<directory>/<script> ..."
echo
