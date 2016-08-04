#/bin/bash
# $1 is the file name
# usage: this_script  <filename>

domain=my.ftp.domain
username=username
password=password
file=$1

echo "
 verbose
 open $domain
 USER $username $password
 put $file
 bye
" | ftp -n > ftp_$$.log
