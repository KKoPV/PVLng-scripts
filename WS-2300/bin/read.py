#!/usr/bin/env python
import sys, os
import argparse, re
import json

sys.path.append(os.path.dirname(os.path.realpath(__file__)) + "/ws2300")
from ws2300 import *

### Helper functions
def printf(format, *args): print format % args

def isFloat(s):
    try: float(s)
    except ValueError: return False

def stripWind(values, ws):
    if ws:
        # Strip "ws" itself 
        values.pop('ws', None)
    # w0 .. w5
    for i in range(6): values.pop('w'+str(i), None)
    values.pop('wt', None)
    return values

### Arguments parser
parser = argparse.ArgumentParser()

parser.add_argument(
    '-c', dest="channels", metavar="channel[,channel...]]", required=True,
    help="Channels to read; see measures.txt for reference"
)
parser.add_argument(
    '-d', dest="device", default='/dev/ttyS0', metavar="<device>",
    help="Device where the WS-2300 is connected; default /dev/ttyS0"
)
parser.add_argument(
    '-o', dest="output", metavar="<file name>",
    type=argparse.FileType('w'),
    help="Output to file, if not given print to stdout"
)
parser.add_argument(
    '-w', dest="nowind", const=True, action='store_const',
    help="Remove wind direction(s) if wind speed is zero"
)
parser.add_argument(
    '-v', dest="verbose", const=True, action='store_const',
    help="Verbose output"
)

args = parser.parse_args()

#print args

# Open port
serialPort = LinuxSerialPort(args.device)

try:

    ws = Ws2300(serialPort)
    HistoryMeasure.set_constants(ws)

    channels = args.channels.split(',')
    for w in ["ws", "wso", "wsv"]:
        if not w in channels: channels.append(w)

    measures = []

    if args.verbose: print "\nChannels to read:\n"

    for key in channels:
        if args.verbose: printf("%-4s: %-30s", key, Measure.IDS[key].name)
        measures.append(Measure.IDS[key])

    # Read data
    data = read_measurements(ws, measures)

    # Get values and string conversions
    if args.verbose: print "\nRaw and converted data:\n"

    values = {}

    for m, d in zip(measures, data):
        val  = m.conv.binary2value(d)
        strg = m.conv.str(val)

        if args.verbose: printf("%-4s: %-30s: %-10s => %s", m.id, Measure.IDS[m.id].name, val, strg)

        # If the string representation of the raw value is also a float,
        # use the numeric value for JSON
        if isFloat(strg) != False: strg = val
        values[m.id] = [ val, strg ]

    # Remove invalid wind data
    if values["wsv"][0] or values["wso"][0]:
        values = stripWind(values, True)

    # Remove wind directions if no wind
    if values["ws"][0] == 0 and args.nowind:
        values = stripWind(values, False)

    # Build result from remaining values, prepare result with timestamp
    result = {
        "Timestamp": datetime.datetime.now().isoformat(),
    }

    for key in values:
        # Use string value here
        result[key] = values[key][1]

    # Output result
    if args.output:
        json.dump(result, args.output)
    if args.verbose or not args.output:
        if args.verbose: print "\nJSON result:\n"
        print json.dumps(result, indent=4)

finally:
    serialPort.close()
