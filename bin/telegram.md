# Script to send status messages to a telegram chat

## Register your bot with @BotFather

    /newbot

Remember the token given by @BotFather!

## Send 1st a test message to your bot via client or web.

This is needed to find out the chat id afterwards with

    $ curl -X POST https://api.telegram.org/bot<token>/getUpdates

## Find and remember the chat id like this:

    {"ok":true,"result":..."chat":{"id":1234567890,...

## Usage

    $ ./telegram.sh token chat message ...
    $ ./telegram.sh token chat @filename

### References

- https://core.telegram.org/bots
- https://core.telegram.org/bots/api
- https://core.telegram.org/bots/samples
