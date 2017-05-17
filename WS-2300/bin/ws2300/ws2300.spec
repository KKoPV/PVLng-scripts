Summary:	Driver for the LaCrosse WS-2300 weather station
Name:		ws2300
Version:	1.9
Release:	1ras
Distribution:	RedHat 7.2 Contrib
Group:		Applications/System
License:	AGPL-3.0+
Packager:	Russell Stuart <russell-rpm@stuart.id.au>
Vendor:		Russell Stuart <russell-ws2300@stuart.id.au>
Url:		http://sourceforge.net/projects/%{name}/files/%{name}-%{version}/%{name}-%{version}.tar.gz
Source:		%{name}-%{version}.tar.gz
BuildArch:	noarch
BuildRoot:	%{_tmppath}/%{name}-root
Requires:	python

%description
Ws2300 manipulates the LaCrosse WS-2300 weather station via its
RS232 interface.  It can read and write values, and can
continuously aggregate and log data from WS-2300 to a file or
SQL database.

%prep
%setup

%build
make

%install
set -xv
rm -rf %{buildroot}
mkdir -p %{buildroot}/usr/lib/python2.7/site-packages/
PYTHONPATH=%{buildroot}/usr/lib/python2.7/site-packages/ make DESTDIR=%{buildroot} install 
mkdir -p %{buildroot}/%{_initddir}
cp ws2300.init %{buildroot}/%{_initddir}/ws2300
mkdir -p %{buildroot}/%{_sysconfdir}/sysconfig
cp ws2300.default %{buildroot}/%{_sysconfdir}/sysconfig/ws2300
rm %{buildroot}/usr/lib/python2.7/site-packages/*.pyc

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root)
%{_bindir}/ws2300
/usr/lib/python2.7/site-packages/ws2300-%{version}-py2.7.egg-info
/usr/lib/python2.7/site-packages/ws2300.py
%{_initddir}/ws2300
%{_sysconfdir}/sysconfig
%doc ChangeLog.txt agpl-3.0.txt README.txt
%doc %{_mandir}/man1/*

%changelog
* Fri Feb 01 2008 Russell Stuart <russell-rpm@stuart.id.au>
- Initial RPM
