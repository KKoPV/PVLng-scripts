#!/usr/bin/python -W default
import warnings; warnings.simplefilter('default')
import distutils.core

description = 'Python driver for the LaCrosse WS-2300 weather station'

classifiers = [
  "Development Status :: 4 - Beta",
  "Environment :: Console",
  "Intended Audience :: Developers",
  "License :: OSI Approved :: AGPL-3.0",
  "Natural Language :: English",
  "Operating System :: Unix",
  "Programming Language :: Python",
  "Topic :: Home Automation"]

distutils.core.setup(
  name="ws2300",
  version="1.9",
  author="Russell Stuart",
  author_email="russell-ws2300@stuart.id.au",
  url="http://conspy.sourceforge.net",
  keywords="weather",
  platforms="Unix",
  long_description=description,
  description=description,
  license="AGPL V3",
  classifiers=classifiers,
  py_modules=["ws2300"],
)
