#!/bin/bash

# example file for -b option

if type apt-add-repository >/dev/null; then
	apt-add-repository multiverse
	apt-add-repository universe
else
	echo "
deb http://de.archive.ubuntu.com/ubuntu/ xenial universe
deb http://de.archive.ubuntu.com/ubuntu/ xenial-updates universe
deb http://de.archive.ubuntu.com/ubuntu/ xenial-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu xenial-security universe
" >> /etc/apt/sources.list
fi

#dpkg-reconfigure keyboard-configuration

# shrink size by removing useless packages
apt -y remove "libreoffic.*"

exit 0

