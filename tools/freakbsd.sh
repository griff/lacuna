#!/bin/sh
#
# Copyright (c) 2005 Poul-Henning Kamp.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
# $FreeBSD: src/tools/tools/freakbsd/freakbsd.sh,v 1.51.2.4.2.1 2010/12/21 17:09:25 kensmith Exp $
#

set -e

#######################################################################
#
# Setup default values for all controlling variables.
# These values can be overridden from the config file(s)
#
#######################################################################

# Name of this FreakBSD build.  (Used to construct workdir names)
FREAK_NAME=full

# Source tree directory
FREAK_SRC=/usr/src

# Where freakbsd additional files live under the source tree
FREAK_TOOLS=tools/tools/nanobsd

# Where cust_pkg() finds packages to install
FREAK_PACKAGE_DIR=${FREAK_SRC}/${FREAK_TOOLS}/Pkg
FREAK_PACKAGE_LIST="*"

# Object tree directory
# default is subdir of /usr/obj
#FREAK_OBJ=""

# The directory to put the final images
# default is ${FREAK_OBJ}
#FREAK_DISKIMGDIR=""

# Parallel Make
FREAK_PMAKE="make -j 3"

# The default name for any image we create.
FREAK_IMGNAME="_.disk.full"

# Options to put in make.conf during buildworld only
CONF_BUILD=' '

# Options to put in make.conf during installworld only
CONF_INSTALL=' '

# Options to put in make.conf during both build- & installworld.
CONF_WORLD=' '

# Kernel config file to use
FREAK_KERNEL=GENERIC

# Customize commands.
FREAK_CUSTOMIZE=""

# Late customize commands.
FREAK_LATE_CUSTOMIZE=""

# Newfs paramters to use
FREAK_NEWFS="-b 4096 -f 512 -i 8192 -O1 -U"

# The drive name of the media at runtime
FREAK_DRIVE=acd0

# Target media size in 512 bytes sectors
FREAK_MEDIASIZE=1200000

# Number of code images on media (1 or 2)
FREAK_IMAGES=2

# 0 -> Leave second image all zeroes so it compresses better.
# 1 -> Initialize second image with a copy of the first
FREAK_INIT_IMG2=1

# Size of code file system in 512 bytes sectors
# If zero, size will be as large as possible.
FREAK_CODESIZE=0

# Size of configuration file system in 512 bytes sectors
# Cannot be zero.
FREAK_CONFSIZE=2048

# Size of data file system in 512 bytes sectors
# If zero: no partition configured.
# If negative: max size possible
FREAK_DATASIZE=0

# Size of the /etc ramdisk in 512 bytes sectors
FREAK_RAM_ETCSIZE=10240

# Size of the /tmp+/var ramdisk in 512 bytes sectors
FREAK_RAM_TMPVARSIZE=10240

# Media geometry, only relevant if bios doesn't understand LBA.
FREAK_SECTS=63
FREAK_HEADS=16

# boot0 flags/options and configuration
FREAK_BOOT0CFG="-o packet -s 1 -m 3"
FREAK_BOOTLOADER="boot/boot0"

# boot2 flags/options
FREAK_BOOT2CFG="-P"

# Backing type of md(4) device
# Can be "file" or "swap"
FREAK_MD_BACKING="file"

# Progress Print level
PPLEVEL=3

#######################################################################
# Architecture to build.  Corresponds to TARGET_ARCH in a buildworld.
# Unfortunately, there's no way to set TARGET at this time, and it 
# conflates the two, so architectures where TARGET != TARGET_ARCH do
# not work.  This defaults to the arch of the current machine.

FREAK_ARCH=`uname -p`

#######################################################################
#
# The functions which do the real work.
# Can be overridden from the config file(s)
#
#######################################################################

clean_build ( ) (
	pprint 2 "Clean and create object directory (${MAKEOBJDIRPREFIX})"

	if ! rm -rf ${MAKEOBJDIRPREFIX} > /dev/null 2>&1 ; then
		chflags -R noschg ${MAKEOBJDIRPREFIX}
		rm -r ${MAKEOBJDIRPREFIX}
	fi
	mkdir -p ${MAKEOBJDIRPREFIX}
	printenv > ${MAKEOBJDIRPREFIX}/_.env
)

make_conf_build ( ) (
	pprint 2 "Construct build make.conf ($FREAK_MAKE_CONF_BUILD)"

	echo "${CONF_WORLD}" > ${FREAK_MAKE_CONF_BUILD}
	echo "${CONF_BUILD}" >> ${FREAK_MAKE_CONF_BUILD}
)

build_world ( ) (
	pprint 2 "run buildworld"
	pprint 3 "log: ${MAKEOBJDIRPREFIX}/_.bw"

	cd ${FREAK_SRC}
	env TARGET_ARCH=${FREAK_ARCH} ${FREAK_PMAKE} \
		__MAKE_CONF=${FREAK_MAKE_CONF_BUILD} buildworld \
		> ${MAKEOBJDIRPREFIX}/_.bw 2>&1
)

build_kernel ( ) (
	pprint 2 "build kernel ($FREAK_KERNEL)"
	pprint 3 "log: ${MAKEOBJDIRPREFIX}/_.bk"

	if [ -f ${FREAK_KERNEL} ] ; then
		cp ${FREAK_KERNEL} ${FREAK_SRC}/sys/${FREAK_ARCH}/conf
	fi

	(cd ${FREAK_SRC};
	# unset these just in case to avoid compiler complaints
	# when cross-building
	unset TARGET_CPUTYPE
	unset TARGET_BIG_ENDIAN
	env TARGET_ARCH=${FREAK_ARCH} ${FREAK_PMAKE} buildkernel \
		__MAKE_CONF=${FREAK_MAKE_CONF_BUILD} KERNCONF=`basename ${FREAK_KERNEL}` \
		> ${MAKEOBJDIRPREFIX}/_.bk 2>&1
	)
)

clean_world ( ) (
	if [ "${FREAK_OBJ}" != "${MAKEOBJDIRPREFIX}" ]; then
		pprint 2 "Clean and create object directory (${FREAK_OBJ})"
		if ! rm -rf ${FREAK_OBJ} > /dev/null 2>&1 ; then
			chflags -R noschg ${FREAK_OBJ}
			rm -r ${FREAK_OBJ}
		fi
		mkdir -p ${FREAK_OBJ} ${FREAK_WORLDDIR}
		printenv > ${FREAK_OBJ}/_.env
	else
		pprint 2 "Clean and create world directory (${FREAK_WORLDDIR})"
		if ! rm -rf ${FREAK_WORLDDIR}/ > /dev/null 2>&1 ; then
			chflags -R noschg ${FREAK_WORLDDIR}
			rm -rf ${FREAK_WORLDDIR}
		fi
		mkdir -p ${FREAK_WORLDDIR}
	fi
)

make_conf_install ( ) (
	pprint 2 "Construct install make.conf ($FREAK_MAKE_CONF_INSTALL)"

	echo "${CONF_WORLD}" > ${FREAK_MAKE_CONF_INSTALL}
	echo "${CONF_INSTALL}" >> ${FREAK_MAKE_CONF_INSTALL}
)

install_world ( ) (
	pprint 2 "installworld"
	pprint 3 "log: ${FREAK_OBJ}/_.iw"

	cd ${FREAK_SRC}
	env TARGET_ARCH=${FREAK_ARCH} \
	${FREAK_PMAKE} __MAKE_CONF=${FREAK_MAKE_CONF_INSTALL} installworld \
		DESTDIR=${FREAK_WORLDDIR} \
		> ${FREAK_OBJ}/_.iw 2>&1
	chflags -R noschg ${FREAK_WORLDDIR}
)

install_etc ( ) (

	pprint 2 "install /etc"
	pprint 3 "log: ${FREAK_OBJ}/_.etc"

	cd ${FREAK_SRC}
	env TARGET_ARCH=${FREAK_ARCH} \
	${FREAK_PMAKE} __MAKE_CONF=${FREAK_MAKE_CONF_INSTALL} distribution \
		DESTDIR=${FREAK_WORLDDIR} \
		> ${FREAK_OBJ}/_.etc 2>&1
	# make.conf doesn't get created by default, but some ports need it
	# so they can spam it.
	cp /dev/null ${FREAK_WORLDDIR}/etc/make.conf
)

install_kernel ( ) (
	pprint 2 "install kernel"
	pprint 3 "log: ${FREAK_OBJ}/_.ik"

	cd ${FREAK_SRC}
	env TARGET_ARCH=${FREAK_ARCH} ${FREAK_PMAKE} installkernel \
		DESTDIR=${FREAK_WORLDDIR} \
		__MAKE_CONF=${FREAK_MAKE_CONF_INSTALL} KERNCONF=`basename ${FREAK_KERNEL}` \
		> ${FREAK_OBJ}/_.ik 2>&1
)

run_customize() (

	pprint 2 "run customize scripts"
	for c in $FREAK_CUSTOMIZE
	do
		pprint 2 "customize \"$c\""
		pprint 3 "log: ${FREAK_OBJ}/_.cust.$c"
		pprint 4 "`type $c`"
		( $c ) > ${FREAK_OBJ}/_.cust.$c 2>&1
	done
)

run_late_customize() (

	pprint 2 "run late customize scripts"
	for c in $FREAK_LATE_CUSTOMIZE
	do
		pprint 2 "late customize \"$c\""
		pprint 3 "log: ${FREAK_OBJ}/_.late_cust.$c"
		pprint 4 "`type $c`"
		( $c ) > ${FREAK_OBJ}/_.late_cust.$c 2>&1
	done
)

setup_freakbsd ( ) (
	pprint 2 "configure freakbsd setup"
	pprint 3 "log: ${FREAK_OBJ}/_.dl"

	(
	cd ${FREAK_WORLDDIR}

	# Move /usr/local/etc to /etc/local so that the /cfg stuff
	# can stomp on it.  Otherwise packages like ipsec-tools which
	# have hardcoded paths under ${prefix}/etc are not tweakable.
	if [ -d usr/local/etc ] ; then
		(
		mkdir -p etc/local
		cd usr/local/etc
		find . -print | cpio -dumpl ../../../etc/local
		cd ..
		rm -rf etc
		ln -s ../../etc/local etc
		)
	fi

	for d in var etc
	do
		# link /$d under /conf
		# we use hard links so we have them both places.
		# the files in /$d will be hidden by the mount.
		# XXX: configure /$d ramdisk size
		mkdir -p conf/base/$d conf/default/$d
		find $d -print | cpio -dumpl conf/base/
	done

	echo "$FREAK_RAM_ETCSIZE" > conf/base/etc/md_size
	echo "$FREAK_RAM_TMPVARSIZE" > conf/base/var/md_size

	# pick up config files from the special partition
	echo "mount -o ro /dev/ufs/cfg" > conf/default/etc/remount
	#touch conf/default/etc/remount_optional

	# Put /tmp on the /var ramdisk (could be symlink already)
	rmdir tmp || true
	rm tmp || true
	ln -s var/tmp tmp

	) > ${FREAK_OBJ}/_.dl 2>&1
)

setup_freakbsd_etc ( ) (
	pprint 2 "configure freakbsd /etc"

	(
	cd ${FREAK_WORLDDIR}

	# create diskless marker file
	touch etc/diskless

	# Make root filesystem R/O by default
	echo "root_rw_mount=NO" >> etc/defaults/rc.conf

	# save config file for scripts
	echo "FREAK_DRIVE=${FREAK_DRIVE}" > etc/freakbsd.conf

	echo "/dev/${FREAK_DRIVE} / cd9660 ro 0 0" > etc/fstab
	echo "/dev/ufs/cfg /cfg ufs rw,noauto 2 0" >> etc/fstab
	mkdir -p cfg
	)
)

prune_usr() (

	# Remove all empty directories in /usr 
	find ${FREAK_WORLDDIR}/usr -type d -depth -print |
		while read d
		do
			rmdir $d > /dev/null 2>&1 || true 
		done
)

populate_slice ( ) (
	local dev dir mnt
	dev=$1
	dir=$2
	mnt=$3
	test -z $2 && dir=/var/empty
	test -d $d || dir=/var/empty
	echo "Creating ${dev} with ${dir} (mounting on ${mnt})"
	newfs ${FREAK_NEWFS} ${dev}
	mount ${dev} ${mnt}
	cd ${dir}
	find . -print | grep -Ev '/(CVS|\.svn)' | cpio -dumpv ${mnt}
	df -i ${mnt}
	umount ${mnt}
)

populate_cfg_slice ( ) (
	populate_slice "$1" "$2" "$3"
)

populate_data_slice ( ) (
	populate_slice "$1" "$2" "$3"
)

create_i386_diskimage ( ) (
	pprint 2 "build isoimage"
	pprint 3 "log: ${FREAK_OBJ}/_.di"

	(
	cd $FREAK_WORLDDIR
	mkisofs -J -R -no-emul-boot -b boot/cdboot -iso-level 3 -o $FREAK_OBJ/_.disk.iso .
	) > ${FREAK_OBJ}/_.di 2>&1
)

# i386 and amd64 are identical for disk images
create_amd64_diskimage ( ) (
	create_i386_diskimage
)

last_orders () (
	# Redefine this function with any last orders you may have
	# after the build completed, for instance to copy the finished
	# image to a more convenient place:
	# cp ${FREAK_DISKIMGDIR}/_.disk.image /home/ftp/pub/freakbsd.disk
)

#######################################################################
#
# Optional convenience functions.
#
#######################################################################

#######################################################################
# Common Flash device geometries
#

FlashDevice () {
	if [ -d ${FREAK_TOOLS} ] ; then
		. ${FREAK_TOOLS}/FlashDevice.sub
	else
		. ${FREAK_SRC}/${FREAK_TOOLS}/FlashDevice.sub
	fi
	sub_FlashDevice $1 $2
}

#######################################################################
# USB device geometries
#
# Usage:
#	UsbDevice Generic 1000	# a generic flash key sold as having 1GB
#
# This function will set FREAK_MEDIASIZE, FREAK_HEADS and FREAK_SECTS for you.
#
# Note that the capacity of a flash key is usually advertised in MB or
# GB, *not* MiB/GiB. As such, the precise number of cylinders available
# for C/H/S geometry may vary depending on the actual flash geometry.
#
# The following generic device layouts are understood:
#  generic           An alias for generic-hdd.
#  generic-hdd       255H 63S/T xxxxC with no MBR restrictions.
#  generic-fdd       64H 32S/T xxxxC with no MBR restrictions.
#
# The generic-hdd device is preferred for flash devices larger than 1GB.
#

UsbDevice () {
	a1=`echo $1 | tr '[:upper:]' '[:lower:]'`
	case $a1 in
	generic-fdd)
		FREAK_HEADS=64
		FREAK_SECTS=32
		FREAK_MEDIASIZE=$(( $2 * 1000 * 1000 / 512 ))
		;;
	generic|generic-hdd)
		FREAK_HEADS=255
		FREAK_SECTS=63
		FREAK_MEDIASIZE=$(( $2 * 1000 * 1000 / 512 ))
		;;
	*)
		echo "Unknown USB flash device"
		exit 2
		;;
	esac
}

#######################################################################
# Setup serial console

cust_comconsole () (
	# Enable getty on console
	sed -i "" -e /tty[du]0/s/off/on/ ${FREAK_WORLDDIR}/etc/ttys

	# Disable getty on syscons devices
	sed -i "" -e '/^ttyv[0-8]/s/	on/	off/' ${FREAK_WORLDDIR}/etc/ttys

	# Tell loader to use serial console early.
	echo "${FREAK_BOOT2CFG}" > ${FREAK_WORLDDIR}/boot.config
)

#######################################################################
# Allow root login via ssh

cust_allow_ssh_root () (
	sed -i "" -e '/PermitRootLogin/s/.*/PermitRootLogin yes/' \
	    ${FREAK_WORLDDIR}/etc/ssh/sshd_config
)

#######################################################################
# Install the stuff under ./Files

cust_install_files () (
	cd ${FREAK_TOOLS}/Files
	find . -print | grep -Ev '/(CVS|\.svn)' | cpio -dumpv ${FREAK_WORLDDIR}
)

#######################################################################
# Install packages from ${FREAK_PACKAGE_DIR}

cust_pkg () (

	# Copy packages into chroot
	mkdir -p ${FREAK_WORLDDIR}/Pkg
	(
		cd ${FREAK_PACKAGE_DIR}
		find ${FREAK_PACKAGE_LIST} -print |
		    cpio -dumpv ${FREAK_WORLDDIR}/Pkg
	)

	# Count & report how many we have to install
	todo=`ls ${FREAK_WORLDDIR}/Pkg | wc -l`
	echo "=== TODO: $todo"
	ls ${FREAK_WORLDDIR}/Pkg
	echo "==="
	while true
	do
		# Record how many we have now
		have=`ls ${FREAK_WORLDDIR}/var/db/pkg | wc -l`

		# Attempt to install more packages
		# ...but no more than 200 at a time due to pkg_add's internal
		# limitations.
		chroot ${FREAK_WORLDDIR} sh -c \
			'ls Pkg/*tbz | xargs -n 200 pkg_add -F' || true

		# See what that got us
		now=`ls ${FREAK_WORLDDIR}/var/db/pkg | wc -l`
		echo "=== NOW $now"
		ls ${FREAK_WORLDDIR}/var/db/pkg
		echo "==="


		if [ $now -eq $todo ] ; then
			echo "DONE $now packages"
			break
		elif [ $now -eq $have ] ; then
			echo "FAILED: Nothing happened on this pass"
			exit 2
		fi
	done
	rm -rf ${FREAK_WORLDDIR}/Pkg
)

#######################################################################
# Convenience function:
# 	Register all args as customize function.

customize_cmd () {
	FREAK_CUSTOMIZE="$FREAK_CUSTOMIZE $*"
}

#######################################################################
# Convenience function:
# 	Register all args as late customize function to run just before
#	image creation.

late_customize_cmd () {
	FREAK_LATE_CUSTOMIZE="$FREAK_LATE_CUSTOMIZE $*"
}

#######################################################################
#
# All set up to go...
#
#######################################################################

# Progress Print
#	Print $2 at level $1.
pprint() {
    if [ "$1" -le $PPLEVEL ]; then
	runtime=$(( `date +%s` - $FREAK_STARTTIME ))
	printf "%s %.${1}s %s\n" "`date -u -r $runtime +%H:%M:%S`" "#####" "$2" 1>&3
    fi
}

usage () {
	(
	echo "Usage: $0 [-biknqvw] [-c config_file]"
	echo "	-b	suppress builds (both kernel and world)"
	echo "	-i	suppress disk image build"
	echo "	-k	suppress buildkernel"
	echo "	-n	add -DNO_CLEAN to buildworld, buildkernel, etc"
	echo "	-q	make output more quiet"
	echo "	-v	make output more verbose"
	echo "	-w	suppress buildworld"
	echo "	-c	specify config file"
	) 1>&2
	exit 2
}

#######################################################################
# Parse arguments

do_clean=true
do_kernel=true
do_world=true
do_image=true

set +e
args=`getopt bc:hiknqvw $*`
if [ $? -ne 0 ] ; then
	usage
	exit 2
fi
set -e

set -- $args
for i
do
	case "$i" 
	in
	-b)
		do_world=false
		do_kernel=false
		shift
		;;
	-k)
		do_kernel=false
		shift
		;;
	-c)
		. "$2"
		shift
		shift
		;;
	-h)
		usage
		;;
	-i)
		do_image=false
		shift
		;;
	-n)
		do_clean=false
		shift
		;;
	-q)
		PPLEVEL=$(($PPLEVEL - 1))
		shift
		;;
	-v)
		PPLEVEL=$(($PPLEVEL + 1))
		shift
		;;
	-w)
		do_world=false
		shift
		;;
	--)
		shift
		break
	esac
done

if [ $# -gt 0 ] ; then
	echo "$0: Extraneous arguments supplied"
	usage
fi

#######################################################################
# Setup and Export Internal variables
#
test -n "${FREAK_OBJ}" || FREAK_OBJ=/usr/obj/freakbsd.${FREAK_NAME}/
test -n "${MAKEOBJDIRPREFIX}" || MAKEOBJDIRPREFIX=${FREAK_OBJ}
test -n "${FREAK_DISKIMGDIR}" || FREAK_DISKIMGDIR=${FREAK_OBJ}

FREAK_WORLDDIR=${FREAK_OBJ}/_.w
FREAK_MAKE_CONF_BUILD=${MAKEOBJDIRPREFIX}/make.conf.build
FREAK_MAKE_CONF_INSTALL=${FREAK_OBJ}/make.conf.install

if [ -d ${FREAK_TOOLS} ] ; then
	true
elif [ -d ${FREAK_SRC}/${FREAK_TOOLS} ] ; then
	FREAK_TOOLS=${FREAK_SRC}/${FREAK_TOOLS}
else
	echo "FREAK_TOOLS directory does not exist" 1>&2
	exit 1
fi

if $do_clean ; then
	true
else
	FREAK_PMAKE="${FREAK_PMAKE} -DNO_CLEAN"
fi

export MAKEOBJDIRPREFIX

export FREAK_ARCH
export FREAK_CODESIZE
export FREAK_CONFSIZE
export FREAK_CUSTOMIZE
export FREAK_DATASIZE
export FREAK_DRIVE
export FREAK_HEADS
export FREAK_IMAGES
export FREAK_IMGNAME
export FREAK_MAKE_CONF_BUILD
export FREAK_MAKE_CONF_INSTALL
export FREAK_MEDIASIZE
export FREAK_NAME
export FREAK_NEWFS
export FREAK_OBJ
export FREAK_PMAKE
export FREAK_SECTS
export FREAK_SRC
export FREAK_TOOLS
export FREAK_WORLDDIR
export FREAK_BOOT0CFG
export FREAK_BOOTLOADER

#######################################################################
# And then it is as simple as that...

# File descriptor 3 is used for logging output, see pprint
exec 3>&1

FREAK_STARTTIME=`date +%s`
pprint 1 "FreakBSD image ${FREAK_NAME} build starting"

if $do_world ; then
	if $do_clean ; then
		clean_build
	else
		pprint 2 "Using existing build tree (as instructed)"
	fi
	make_conf_build
	build_world
else
	pprint 2 "Skipping buildworld (as instructed)"
fi

if $do_kernel ; then
	build_kernel
else
	pprint 2 "Skipping buildkernel (as instructed)"
fi

clean_world
make_conf_install
install_world
install_etc
setup_freakbsd_etc
install_kernel

run_customize
setup_freakbsd
prune_usr
run_late_customize
if $do_image ; then
	create_${FREAK_ARCH}_diskimage
else
	pprint 2 "Skipping image build (as instructed)"
fi
last_orders

pprint 1 "FreakBSD image ${FREAK_NAME} completed"
