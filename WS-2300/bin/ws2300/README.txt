ws2300
======

  Ws2300 is a driver for the LaCrosse WS-2300 weather station.

  How to use ws2300 is documented in its man page.

  All documentation is readable online at the home page:
    http://ws2300.sourceforge.net/


Dependencies
------------

  Python >= 2.6


Building and Installing
-----------------------

  Packages are available for Debian and RedHat style
  distributions at the home page.  If you install using one
  of those methods you can skip this section.

  Building is optional.  There is only one source file and
  it can be used directly.

  The build dependencies are:
    - A POSIX system (make, unix shell, sed, etc).

  Ws2300 is written entirely in a interpreted language, so no
  compiling is necessary.

  To install, in the directory containing this file run:
    make install


Configuring
-----------

  To start automatically on boot up:

    In the distribution you will find a sysV init script called
    ws2300.rc.  You can copy this into your sysV /etc/rc*.d and
    /etc/init.d directories to make the ws2300 daemon start
    automatically on boot.  ws2300.rc reads the config files
    /etc/default/ws2300 and /etc/sysconfig/ws2300 to figure out
    what to do.  An example config is provided in ws2300.default,
    see the comments in there for more information.  ws2300.rc
    will only start the ws2300 daemon configuration file passed
    to 'ws2300 tty record configuration-file' is present.  The
    default name for configuration file is /etc/ws2300/ws2300.conf.


License
-------

  Copyright (c) 2007-2014, Russell Stuart.

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU Affero General Public License as published
  by the Free Software Foundation, either version 3 of the License, or (at
  your option) any later version.

  The copyright holders grant you an additional permission under Section 7
  of the GNU Affero General Public License, version 3, exempting you from
  the requirement in Section 6 of the GNU General Public License, version 3,
  to accompany Corresponding Source with Installation Information for the
  Program or any work based on the Program. You are still required to
  comply with all other Section 6 requirements to provide Corresponding
  Source.

  This program is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
  Affero General Public License for more details.


--
Russell Stuart
2014-Jun-06
