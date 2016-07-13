# Setup

    $ git clone https://github.com/tgalal/yowsup /src/yowsup
    $ cd /src/yowsup
    $ sudo python setup.py install
    # Go back to .../PVLng-scripts/bin
    $ cd -
    $ sudo rm -rf /src/yowsup
    # Prepare config file
    $ cp yowsup.conf.dist yowsup.conf

## Change now your telefon number

    $ $EDITOR yowsup.conf

## Request SMS with registration code for your telefon number

    $ yowsup-cli registration -c yowsup.conf --requestcode sms

    ...
    status: sent
    retry_after: 64
    length: 6
    method: sms

## Register with the registration code from the SMS

    $ yowsup-cli registration -c yowsup.conf --register 000-000

    ...
    status: ok
    ...
    pw: **********************
    ...

## Set the password

    $ $EDITOR yowsup.conf

## 1st run for key generation...

    $ ./yowsup.sh 4911111111111 'Hallo Welt'

    ...
    IOError: [Errno 13] Permission denied: '/usr/local/lib/python2.7/dist-packages/protobuf-3.0.0b3-py2.7.egg/EGG-INFO/namespace_packages.txt'

## The file name(s) can differ, but make the denied file(s) world readable

    $ sudo chmod +r /usr/local/lib/python2.7/dist-packages/protobuf-3.0.0b3-py2.7.egg/EGG-INFO/namespace_packages.txt
    $ sudo chmod +r /usr/local/lib/python2.7/dist-packages/protobuf-3.0.0b3-py2.7.egg/EGG-INFO/requires.txt

## Run again...

    $ ./yowsup.sh 4911111111111 'Hallo Welt'

## You should receive the message...

---

Based on
* https://github.com/tgalal/yowsup
* https://www.johannespetz.de/yowsup-cli-linux-whatsapp-nachrichten-verschicken/
