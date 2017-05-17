#!/usr/bin/env python
import sys, os
import argparse
from ws2300 import *

### Helper function
def printf(format, *args): print format % args

### Arguments parser
parser = argparse.ArgumentParser()

parser.add_argument(
    '-d', dest="device", default='/dev/ttyS0', metavar="<device>",
    help="Device where the WS-2300 is connected; default /dev/ttyS0"
)

args = parser.parse_args()

# Open port
serialPort = LinuxSerialPort(args.device)

try:

    ws = Ws2300(serialPort)
    HistoryMeasure.set_constants(ws)

    # Collect measures to do
    measures = []

    for id in Measure.IDS:
        measures.append(Measure.IDS[id])

    # Read data
    data = read_measurements(ws, measures)

    # Buffer data for sorting
    values = {}
    for m, d in zip(measures, data):
        values[m.id] = [ m, d ]

    for key in sorted(values):
        m, d = values[key]
        v = m.conv.binary2value(d)
        printf("%-30s [%-4s] %-15s => %s", m.name, m.id, v, m.conv.str(v))

finally:
    serialPort.close()
