#!/bin/bash

function usage() {
    echo "Usage: $0 token chat message ..."
    echo "       $0 token chat @filename"
    exit ${1:-0}
}

[ -z "$3" ] && usage

### Just hard coded parameter order...
token=$1
chat_id=$2

### Is the 3rd given parameter a file name (starting with @)?
if [ ${3:0:1} == @ ]; then
    ### Use file direct as message
    text=${3:1}
else
    ### Use all remaining parameters as message
    shift 2 # token and chat id
    text=$(mktemp)
    trap 'rm $text' 0
    echo "$@" >$text
fi

### Send message, returns JSON string
curl --data chat_id=$chat_id --data-urlencode text@$text https://api.telegram.org/bot$token/sendMessage
