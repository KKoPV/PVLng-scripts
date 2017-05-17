To use green LED as heartbeat and red LED flash for each impule handled,
insert this in `/etc/rc.loacl` **before** `exit 0`!

    # Own control of LEDs
    echo none > /sys/class/leds/led0/trigger
    echo 0    > /sys/class/leds/led0/brightness
    echo none > /sys/class/leds/led1/trigger
    echo 0    > /sys/class/leds/led1/brightness
