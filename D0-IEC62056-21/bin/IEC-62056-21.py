#!/usr/bin/python
##############################################################################
###
###
###
###
### Adapted from
### http://wiki.volkszaehler.org/hardware/channels/meters/power/edl-ehz/iskraemeco_mt171
##############################################################################
import sys, getopt, serial, time

##############################################################################
### Some default settings
##############################################################################
DEVICE = '/dev/ttyUSB0'
TRIES  = 5
SLEEP  = 3

##############################################################################
### Sends an command to serial device and reads and checks the echo
### port   - the open serial port
### bytes  - the string to be send
### tr     - the responce time
##############################################################################
def send( port, bytes, tr ):
    bytes = bytes.encode('ascii')
    log(2, "> '" + bytes.strip() + "' (" + bytes.encode('hex') + ') ...')
    port.write(bytes)
    time.sleep(tr)
    echo = port.read(len(bytes))
    time.sleep(tr)
    if (echo != bytes):
        log(1, 'echo is not same as send: "' + bytes + '" vs "' + echo + '"')

##############################################################################
### Read one byte from serial device
### port - the open serial port
##############################################################################
def read1( port ):
    x = o = port.read().decode('ascii')
    if (ord(o) < 32): o = ' '
    log(3, "< '" + o + "' (" + x.encode('hex') + ')')
    return x

##############################################################################
### Mapping of energy meter speed id to serial baud rate
Speed2Baud = {'0':300, '1':600, '2':1200, '3':2400, '4':4800, '5':9600, '6':19200}

### Does all that's needed to get meter data from the meter device
##############################################################################
def readData( device, raw ):
    ACK = '\x06'
    STX = '\x02'
    ETX = '\x03'
    tr = 0.2

    try:
        ### Open port at specified speed
        EnergyMeter = serial.Serial(port=device, baudrate=300, bytesize=7, \
                                    parity='E', stopbits=1, timeout=1.5);
        time.sleep(tr)

        ### 1 ->
        ### Init request
        ### IEC 62056-21:2002(E) 6.3.1
        send(EnergyMeter, '/?!\r\n', tr)

        ### 2 <-
        ### Identification
        ### IEC 62056-21:2002(E) 6.3.2
        IdMsg = EnergyMeter.readline()
        log(1, 'Identification: ' + IdMsg)

        if (IdMsg[0] != '/'):
            log(1, 'No Identification message')
            EnergyMeter.close()
            return ''
        if (len(IdMsg) < 7):
            log(1, 'Identification message to short')
            EnergyMeter.close()
            return ''

        ### Switch speed
        speed = IdMsg[4]

# ???   if (IdMsg[4].islower()): tr = 0.02

        ### Fallback to 300 baud?
        if (not speed in Speed2Baud): speed = '0'
        log(1, 'New speed: ' + str(Speed2Baud[speed]) + ' baud')

        ### 3 ->
        ### Acknowledgement with new baud rate
        ### IEC 62056-21:2002(E) 6.3.3
        send(EnergyMeter, ACK + '0' + speed + '0\r\n', tr)
        ### Set new speed AFTER send
        EnergyMeter.baudrate = Speed2Baud[speed]

        ### 4 <-
        ### Read data
        if (raw): return ''.join(EnergyMeter.readlines())

        data = ''
        if (read1(EnergyMeter) == STX):
            x = read1(EnergyMeter)
            BCC = 0
            while (x != '!'):
                BCC = BCC ^ ord(x)
                data += x
                x = read1(EnergyMeter)
            while (x != ETX):
                ### ETX itself is part of block check
                BCC = BCC ^ ord(x)
                x = read1(EnergyMeter)
            BCC = BCC ^ ord(x)
            x = read1(EnergyMeter)
            ### x is now the Block Check Character
            ### Last character is read, could close connection here
            if (BCC != ord(x)): # received correctly?
                log(1, 'Result not OK, try again ...')
                data = ''
            EnergyMeter.close()
        else:
            log(1, 'No STX found, try again ...')
    except:
        if (not 'EnergyMeter' in locals()):
            usage(3, "Can't open device '" + device + "'")
        else:
            log(1, 'Some error reading data')
            if (EnergyMeter.isOpen()): EnergyMeter.close()
            data = ''

    return data

##############################################################################
### Script usage help
### rc    - Return code to send
### error - Message to output
##############################################################################
def usage( rc=0, error=None ):
    print
    if (error): print 'ERROR: ' + str(error) + '!\n'
    print 'Read data from energy meters with optical D0 interface according to IEC 62056-21'
    print '(see https://en.wikipedia.org/wiki/IEC_62056#IEC_62056-21)\n'
    print 'Usage:', sys.argv[0], '[options]\n'
    print 'Options:'
    print '\t-d, --device \tDevice where the D0 reader is connected to'
    print "\t             \tdefault '" + DEVICE + "'"
    print '\t-t, --tries  \tHow many tries to get data before give up'
    print "\t             \tdefault " + str(TRIES)
    print '\t-v, --verbose\tVerbose mode, write some info to STDERR'
    print '\t-vv          \tDebug mode'
    print '\t-h, --help   \tThis help\n'
    sys.exit(rc)

##############################################################################
### Log depending of verbose level
##############################################################################
def log( level, msg ):
    if (VERBOSE >= level):
        sys.stderr.write('['+time.strftime("%H:%M:%S")+'] '+msg.strip()+'\n')

##############################################################################
### Main program
##############################################################################
RAW     = False
VERBOSE = 0

### Analyse command line parameters
try:
    opts, args = getopt.getopt(sys.argv[1:], "d:rt:vh", ['device=','raw','tries=','verbose','help'])
except getopt.GetoptError as error:
    usage(2, str(error))

for opt, arg in opts:
    if   opt in ('-d', '--device'):   DEVICE   = arg
    elif opt in ('-r', '--raw'):      RAW      = True
    elif opt in ('-t', '--tries'):
        try:
            TRIES = int(arg)
        except:
            usage(1, 'Parameter for -t/--tries must by an integer!')
    elif opt in ('-v', '--verbose'):  VERBOSE += 1
    elif opt in ('-h', '--help'):     usage()

###
### Let's go
###
log(1, 'Device: ' + DEVICE)
log(1, 'Tries : ' + str(TRIES))

### Loop until we got at least one correct reading, but max. 10 tries
data  = ''

while (data == ''):

    ### Read data from device
    data = readData(DEVICE, RAW)

    if (data != ''):
        ### Got data

        if (RAW):
            print data
        else:
            ### Loop data, extract address and value
            for line in data.split('\n'):
                if (line == ''): continue

                x = line.split('(')
                address = x[0]
                ### Remove ) and new line
                x = x[1].split(')')
                value = x[0]
                ### Remove unit from value
                ### The standard have a '*' between value and unit
                x = value.split('*')
                value = x[0]
                ### But also test for a space here ...
                x = value.split(' ')
                value = x[0]

                print address + '\t' + value

        sys.exit(0);

    ### No data, try again ...
    log(1, 'No data received')

    TRIES -= 1
    if (TRIES <= 0): sys.exit(0)
    log(1, str(TRIES) + ' tries left')

    ### Minimum waiting time is 3 seconds,
    ### less and the meter doesn't return data
    time.sleep(SLEEP)
