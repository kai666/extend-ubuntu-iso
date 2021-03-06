#!/bin/bash

###
### script to extend existing ubuntu image with
### some deb packages
###
###
# Copyright (c) 2017 Kai Doernemann (kai_AT_doernemann.net)
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# 3. The name of the author may not be used to endorse or promote products
#    derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY KAI DOERNEMANN "AS IS" AND ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
# OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
###

RED='\033[31m'
GREEN='\033[32m'
NORMAL='\033[0m'
CALLDIR="${PWD}"
UNIONMOUNT=""

function absolute () {
	local _x="$1"
	[ -n "${_x##/*}" ] && _x="${PWD}/$_x"
	echo "${_x}"
}

absolute_me="`absolute "$0"`"
mini_me=`basename $0`

function usage () {
	echo "$mini_me [opts] ubuntu.iso [package1.deb ... packageN.deb]

extend Ubuntu live ISO image with a list of debian format packages
(so you can add commands to your live CD without much effort)

options:
	-A <cmd>		execute command inside chroot env,
				after apt-get update/upgrade/autoremove run
	-B <cmd>		execute command inside chroot env,
				before apt run
	-C <pathname>		use directory as cache for APT
	-d			call shell inside chroot after apt run
				and command from -A
	-h			show this help
	-O <pathname>		name of output file, default
				is <input>-custom.iso
	-R <repository>		add repository type, e.g. 'universe'
				multiple occurrences allowed
	-U <pathname>		write ISO directly to USB stick mounted here
	-v			show version number
	-x inside_chroot	internal use, call myself inside_chroot
" >&2
	exit 2
}
function die () {
	echo -e "${RED}${mini_me}: $@${NORMAL}" >&2
	exit 2
}
function info () {
	echo -e "${GREEN}${mini_me}: $@${NORMAL}"
}
function atexit () {
	info "cleaning up"
	cd /
	if [ -n "$UNIONMOUNT" ]; then
		sudo umount "$UNIONMOUNT"
	fi
	if [ -n "$ISOMOUNT" ]; then
		sudo umount "$ISOMOUNT"
		rmdir "$ISOMOUNT"
	fi
	if [ -d "$WORKDIR" ]; then
		sudo umount $WORKDIR/edit/dev
		sudo umount $WORKDIR/edit/run
		sudo rm -rf "$WORKDIR"
	fi
}
function require () {
	for x in $@; do
		[ -x "$x" ] || die "cannot execute '$x'"
	done
}
function apt_add_repo () {
	local _repos="$@"

	if type apt-add-repository 1>/dev/null 2>/dev/null; then
		for repo in ${_repos}; do
			apt-add-repository "$repo"
		done
	else
		sed -i.bak -e "s/\bmain\b/main ${_repos}/g" /etc/apt/sources.list
	fi
}
function inside_chroot () {
	# I'm root here!
	export HOME=/root
	export LC_ALL=C
	mount -t proc   none /proc
	mount -t sysfs  none /sys
	mount -t devpts none /dev/pts

	mv /etc/resolv.conf /etc/resolv.conf.orig

	cd /tmp/extend-ubuntu
	cp resolv.conf /etc/
	[ -x ./chroot-before ] && ./chroot-before

	[ -n "$DO_REPO" ] && apt_add_repo "$DO_REPO"

	$DO_UPDATE	&& apt-get -y update
	$DO_UPGRADE	&& apt-get -y upgrade
	if ls *.deb 1>/dev/null 2>/dev/null; then
		set -- `apt-get --version`
		version="$2"		# 1.2.24
		set -- `echo $version | sed -e 's/\./ /g'`
		major="$1"		# 1
		minor="$2"		# 2
		sub="$3"		# 24
		modern_apt=false
		[ $major -gt 1 ] && modern_apt=true
		[ $major -eq 1 -a $minor -ge 1 ] && modern_apt=true
		if $modern_apt; then
			# since ubuntu 16
			for deb in *.deb; do
				apt-get -y install ./$deb
			done
		else
			# ubuntu <= 14.04 (at least)
			dpkg -i *.deb
			$DO_FIX && apt-get -y -f install
		fi
	fi
	$DO_AUTOREMOVE	&& apt-get -y autoremove

	[ -x ./chroot-after ] && ./chroot-after

	$DO_DEBUG	&& bash -i

	dpkg-query -W --showformat='${Package} ${Version}\n' > /tmp/extend-ubuntu/filesystem.manifest

	mv /etc/resolv.conf.orig /etc/resolv.conf

	umount /dev/pts
	umount /sys
	umount /proc

	exit 0
}

###
### MAIN
###
SAVE_ARGS=("$@")
[ $# -lt 1 ] && usage
# inherit -x-option when calling bash inside this script
case $- in
	*x*) USE_X="-x";;
	  *) USE_X=;;
esac
DO_UPDATE=true
DO_UPGRADE=false
DO_FIX=true
DO_AUTOREMOVE=true
DO_DEBUG=false
DO_EXECUTE=""		# execute 'inside_chroot'?
DO_AFTER=""		# script to run after operations inside_chroot
DO_BEFORE=""		# script to run before operations inside_chroot
DO_APTCACHE=""		# directory to use as cache dir for APT data
DO_USB=""		# write ISO to USB stick
DO_REPO=""		# add these repos before installing .deb packages
while getopts ":hx:A:B:C:dO:R:U:v" opt; do
	case "${opt}" in
	"h")	usage ;;
	"x")	DO_EXECUTE="${OPTARG}"
		[ "$DO_EXECUTE" != "inside_chroot" ] && die "only option: -x inside_chroot"
		;;
	"A")	DO_AFTER="${OPTARG}"	;;
	"B")	DO_BEFORE="${OPTARG}"	;;
	"C")	DO_APTCACHE="`absolute "${OPTARG}"`"	;;
	"d")	DO_DEBUG=true		;;
	"O")	OUTPUT_ISO="`absolute "${OPTARG}"`"	;;
	"R")	DO_REPO="${DO_REPO} ${OPTARG}" ;;
	"U")	DO_USB="${OPTARG}"	;;
	"v")	cat ./gitref 2>/dev/null || cat /usr/share/extend-ubuntu-iso/gitref
		exit  0
		;;
	":")	die "${OPTARG} requires an argument" ;;
	\?)	die "invalid option -$OPTARG" ;;
	esac
done
while [ $OPTIND -gt 1 ]; do
	OPTIND=$(( $OPTIND - 1 ))
	shift
done
# jump to chroot if requested
[ -n "$DO_EXECUTE" ] && inside_chroot

# this is to prepare chroot, call chroot and create ISO
require "${DO_AFTER}"
require "${DO_BEFORE}"
ISO="`absolute "$1"`"
[ -r "$ISO" ] || die "ISO file $ISO not readable or not existing"
shift
if [ -z "$OUTPUT_ISO" ]; then
	OUTPUT_ISO="`basename "$ISO"`"
	OUTPUT_ISO="${CALLDIR}/${OUTPUT_ISO%%.iso}-custom.iso"
fi
[ -e "$OUTPUT_ISO" ] && die "target $OUTPUT_ISO already exists - remove manually"
PACKAGES="$@"
for p in $PACKAGES; do
	[ -r "$p" ] || die "package $p not readable or not existing"
done
if [ -n "$DO_APTCACHE" ]; then
	[ ! -d "$DO_APTCACHE" ] && die "$DO_APTCACHE is no directory"
	for d in "$DO_APTCACHE/var/cache/apt" "$DO_APTCACHE/var/lib/apt"; do
		test -d "$d" || mkdir -p "$d" || die "cannot mkdir -p $d"
	done
fi
# sudo apt install squashfs-tools genisoimage xorriso

info "mount iso readable"
trap atexit 1 2 9 15
ISOMOUNT=`mktemp -d /tmp/tmp.exubXXXXXX`
sudo mount -o loop,ro "$ISO" "$ISOMOUNT" || die "cannot mount $ISO to $ISOMOUNT"

info "unsquash root fs"
WORKDIR=`mktemp -d /tmp/tmp.exubXXXXXX`
pushd "$WORKDIR"
SQUASHSOURCE=""
SQUASHTARGET=""
for p in casper/filesystem.squashfs install/filesystem.squashfs; do
	if [ -r "$ISOMOUNT/$p" ]; then
		SQUASHSOURCE="$ISOMOUNT/$p"
		SQUASHTARGET="$p"
	fi
done
[ -z "$SQUASHSOURCE" ] && die "cannot find squashfs in $ISO"
sudo unsquashfs $SQUASHSOURCE
sudo mv squashfs-root edit
popd

info "setup chroot environment"
# WARNING: If you do this in 14.04 LTS, you will lose network connectivity
# (name resolving part of it). /etc/resolv.conf is and should remain a symlink
# to /run/resolvconf/resolv.conf nowadays. To enable name resolving,
# temporarily edit that file instead. If you need the network connection
# within chroot

wete="$WORKDIR/edit/tmp/extend-ubuntu"
sudo mkdir $wete
sudo cp "$absolute_me" $wete/
sudo cp /etc/resolv.conf $wete/
[ -n "$PACKAGES" ]  && sudo cp $PACKAGES $wete/
[ -n "$DO_BEFORE" ] && sudo install -m 0755 "$DO_BEFORE" $wete/chroot-before
[ -n "$DO_AFTER" ]  && sudo install -m 0755 "$DO_AFTER"  $wete/chroot-after

#sudo cp /etc/resolv.conf edit/etc/
# XXX: -o ro not working here because deb-packages possibly trigger makedev etc.
sudo mount --bind /run/ $WORKDIR/edit/run
sudo mount --bind /dev/ $WORKDIR/edit/dev
if [ -n "$DO_APTCACHE" ]; then
	sudo rsync -Cau $WORKDIR/edit/var/lib/apt "$DO_APTCACHE/var/lib/apt"
	sudo rsync -Cau $WORKDIR/edit/var/cache/apt "$DO_APTCACHE/var/cache/apt"
	sudo mount --bind "$DO_APTCACHE/var/cache/apt" $WORKDIR/edit/var/cache/apt
	sudo mount --bind "$DO_APTCACHE/var/lib/apt" $WORKDIR/edit/var/lib/apt
fi
info "do the work inside the chroot"
sudo chroot $WORKDIR/edit bash $USE_X /tmp/extend-ubuntu/$mini_me \
	-x inside_chroot "${SAVE_ARGS[@]}"

info "return from chroot here..."
if [ -n "$DO_APTCACHE" ]; then
	sudo umount $WORKDIR/edit/var/lib/apt
	sudo umount $WORKDIR/edit/var/cache/apt
fi
sudo umount $WORKDIR/edit/dev
sudo umount $WORKDIR/edit/run

# filesystem.manifest was generated inside chroot, we need it for
# rebuilding CD
sudo mv $wete/filesystem.manifest $WORKDIR/

info "cleanup tmp inside squashfs area"
sudo /bin/rm -rf $wete/

info "generate new squashfs"
# XXX: this has to be generated for the kernel on the CD.
# Also, the squashfs has to be generated using a version of mksquashfs that
# is compatible with the kernel used on the CD you are customizing.
# For example, you cannot generate a jaunty squashfs on karmic, as the jaunty
# kernel is not able to mount a squashfs prepared using mksquashfs from karmic.
sudo mksquashfs $WORKDIR/edit $WORKDIR/filesystem.squashfs
sudo du -sx --block-size=1 $WORKDIR/edit | cut -f1 > $WORKDIR/filesystem.size

info "delete edited squashfs filesystem source"
sudo /bin/rm -rf edit

info "copy CD contents, create new tree in $WORKDIR/newcd"
mkdir $WORKDIR/newcd

if true; then
	# use union mount instead of rsync ...
	sudo mount -t aufs -o br=$WORKDIR/newcd:$ISOMOUNT none $WORKDIR/newcd
	UNIONMOUNT="$WORKDIR/newcd"
	cd $WORKDIR/newcd
else
	# use rsync instead of union mount
	cd $WORKDIR/newcd
	sudo rsync -a $ISOMOUNT/ .
fi

# move changed files in their right place
sudo mv $WORKDIR/filesystem.* "`dirname $SQUASHTARGET`/"
# create new md5sum.txt
sudo rm md5sum.txt
sudo bash -c "find . -type f -print0 | xargs -0 md5sum | grep -v isolinux/boot.cat | tee md5sum.txt"

info "create new ISO $OUTPUT_ISO"
# set -- Volume id: Ubuntu 14.04.5 LTS amd64
set -- `isoinfo -d -i "$ISO" | grep -i "volume id:"`
shift
shift
# maximum length for volid is 32 chars
VOLID=`echo -n "$@" "customized" | cut -c -32`
### only? xorriso can build images with correct UEFI setup
# read UEFI boot block from $ISO
dd if="$ISO" bs=512 count=1 of=$WORKDIR/isohdpfx.bin
xorriso -as mkisofs \
	-isohybrid-mbr $WORKDIR/isohdpfx.bin \
	-c isolinux/boot.cat \
	-b isolinux/isolinux.bin \
	-no-emul-boot \
	-boot-load-size 4 \
	-boot-info-table \
	-eltorito-alt-boot \
	-e boot/grub/efi.img \
	-no-emul-boot \
	-isohybrid-gpt-basdat \
	-volid "$VOLID" \
	-o "$OUTPUT_ISO" .

if [ -n "$DO_USB" ]; then
	info "extract ISO to directory $DO_USB"
	7z x "$OUTPUT_ISO" -o"$DO_USB/"

	# mark partition bootable
	set -- `df "$DO_USB" | grep '^/' | head -1`
	drvpartno="$1"
	drive="${drvpartno%[0-9]*}"		# extract drive
	partno="${drvpartno//[!0-9]/}"		# extract number
	info "mark $drive partition $partno as bootable"
	sudo parted $drive set $partno boot on
fi

atexit

exit 0
