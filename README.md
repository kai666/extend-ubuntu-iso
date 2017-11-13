# extend-ubuntu-iso
shell script to extend an existing ubuntu ISO image with .deb packets

# to build
Just type 'make' and 'make deb'. Then 'sudo dpkg -i *.deb'

# usage
try "extend-ubuntu-iso -h"

examples:

	$ extend-ubuntu-iso ubuntu-16.04.2-desktop-amd64.iso yourfunkypackage.deb
	
	$ extend-ubuntu-iso -R multiverse -R universe ubuntu-16.04.2-desktop-amd64.iso yourfunkypackage.deb

upgrade the packages of  an existing cd with

	$ extend-ubuntu-iso ubuntu-16.04.2-desktop-amd64.iso
