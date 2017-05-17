#!/usr/bin/env python

# http://raspberrypi.stackexchange.com/a/36245

import sys, getopt, datetime, time, signal
import RPi.GPIO as GPIO

try:
    from urllib.request import Request, urlopen  # Python 3
except:
    from urllib2 import Request, urlopen  # Python 2

### --------------------------------------------------------------------------
### Settings
### --------------------------------------------------------------------------

LED_heartbeat = 47          ### Pin for green LED
LED_impulse   = 35          ### Pin for red LED

options = {
    'pin':        23,       ### A common GPIO pin
    'resolution': 1000,     ### Impulse per kilo watt hour
    'bounce':     300,      ### milli seconds
    'log':        False,    ### Foreground
    'verbose':    0         ### Off
}

### --------------------------------------------------------------------------
### Functions
### --------------------------------------------------------------------------
def usage(rc):
    print('''
Listen for S0 impulses on a Raspberry GPIO pin

Usage: %s [options]

Options:
    -p <PIN>              GPIO pin to listen for impulses, default 23
    -r <resolution>       Impulses per kilo watt hour, default 1000
    -b <milli seconds>    Pin bounce time, default, 300ms
    -l <file name>        Log file to store watts values
                          If not given, script will run in foreground
    -v                    Verbose mode
    -h                    This help
''' % sys.argv[0])
    sys.exit(rc)

### --------------------------------------------------------------------------
def log(level, format, *args):
    if options['verbose'] >= level:
        print('[' + str(datetime.datetime.now()) + '] ' + format % args)

### --------------------------------------------------------------------------
### Make argument integer or throw error message
### --------------------------------------------------------------------------
def int_arg(arg, msg):
    try:
        return int(arg)
    except:
        print('\n%s: %s\n' % (msg, arg))
        sys.exit()

### --------------------------------------------------------------------------
### Init last timestamp pointer
last_timestamp = False

### --------------------------------------------------------------------------
def handleImpulse(event):

    ### At 1st remember actual time for precise calculations
    timestamp = time.time()

    ### Turn notification LED on, also during wait for 2nd impulse
    GPIO.output(LED_impulse, True)

    ### Import to change
    global last_timestamp

    if not last_timestamp:
        log(1, 'Start measuring ...')
        last_timestamp = timestamp
        return

    watts = 36e5 / (timestamp - last_timestamp) / options['resolution']

    if options['log']:
        with open(options['log'], 'a') as f:
            f.write(str(watts) + '\n')
            f.close()

    log(1, '%9.3f W', watts)

    time.sleep(0.05)

    ### Turn notification LED off
    GPIO.output(LED_impulse, False)

    last_timestamp = timestamp

### --------------------------------------------------------------------------
def cleanup(signal, frame):
    GPIO.cleanup()
    sys.exit(0)

### --------------------------------------------------------------------------
### Command line arguments
### --------------------------------------------------------------------------
try:
    opts, args = getopt.getopt(sys.argv[1:], "p:r:b:l:vh")
except getopt.GetoptError:
    usage(2)

### --------------------------------------------------------------------------
for opt, arg in opts:
    if opt == '-p':
        options['pin'] = int_arg(arg, 'Invalid PIN number')
    elif opt == '-r':
        options['resolution'] = int_arg(arg, 'Invalid resolution')
    elif opt == '-b':
        options['bounce'] = int_arg(arg, 'Invalid bounce time')
    elif opt == '-l':
        options['log'] = arg
        try:
            with open(options['log'], 'a') as f: f.close()
        except:
            print('\nCan\'t open log file: %s\n' % options['log'])
            usage(1)
    elif opt == '-v':
        options['verbose'] += 1
    else:
        usage(0)

### --------------------------------------------------------------------------
### Let's go
### --------------------------------------------------------------------------
log(2, '--- Configuration ---')
for (key, value) in options.items():
    log(2, '%-10s = %s', key, value)
log(2, '---------------------')

### Check log file given
if not options['log']:
    options['verbose'] += 1
    log(1, 'No log file given, run in foreground')
    log(1, 'Press <Ctrl>+C to abort')

### Init GPIO
GPIO.setwarnings(False)
GPIO.setmode(GPIO.BCM)

### Init LEDs and turn them off
GPIO.setup(LED_heartbeat, GPIO.OUT)
GPIO.output(LED_heartbeat, False)

GPIO.setup(LED_impulse, GPIO.OUT)
GPIO.output(LED_impulse, False)

### Set up pin as input, pulled up to avoid false detection.
### It is wired to connect to GND on impulse.
### So we'll be setting up falling edge detection
GPIO.setup(options['pin'], GPIO.IN, pull_up_down=GPIO.PUD_UP)

### When a falling edge is detected, regardless of whatever
### else is happening in the program, the function handleImpulse will be run
### 'bouncetime' includes the bounce control written into interrupts2a.py
GPIO.add_event_detect(options['pin'], GPIO.FALLING, callback=handleImpulse, bouncetime=options['bounce'])

### Catch <CRTL>+C silently
signal.signal(signal.SIGINT, cleanup)

###
log(1, 'Wait for 1st impulse ...')

# Make the heartbeat LED flash all the time
while True:
    GPIO.output(LED_heartbeat, True)
    time.sleep(1)
    GPIO.output(LED_heartbeat, False)
    time.sleep(1)

cleanup()
