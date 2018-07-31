#!/bin/bash

#
# set all necessary vars and functions
#
# (c) 2007-2016, Hetzner Online GmbH
#

DEBUGFILE=/root/debug.txt


# set up standard env
export SCRIPTPATH; SCRIPTPATH=$(dirname "$0")
export DISABLEDFILE="$SCRIPTPATH/disabled"
export SETUPFILE="$SCRIPTPATH/setup.sh"
export AUTOSETUPFILE="$SCRIPTPATH/autosetup.sh"
export AUTOSETUPCONFIG="/autosetup"
export INSTALLFILE="$SCRIPTPATH/install.sh"
export FUNCTIONSFILE="$SCRIPTPATH/functions.sh"
export GETOPTIONSFILE="$SCRIPTPATH/get_options.sh"
export STANDARDCONFIG="$SCRIPTPATH/standard.conf"
export CONFIGSPATH="$SCRIPTPATH/configs"
export POSTINSTALLPATH="$SCRIPTPATH/post-install"
export POSTINSTALLURL=""
export IMAGESPATH="$SCRIPTPATH/../images/"
export OLDIMAGESPATH="$SCRIPTPATH/../images.old/"
export IMAGESPATHTYPE="local"
export IMAGESEXT="tar.gz"
export IMAGEFILETYPE="tgz"
export COMPANY_PUBKEY="$SCRIPTPATH/gpg/public-key.asc"
export COMPANY="Example Awesome Company"
export C_SHORT="example"
export SLEEP_BEFORE_START="20"
export SLEEP_BEFORE_REBOOT="20"
export INSTALLSTATUS_URL=""

export MODULES="virtio_pci virtio_blk via82cxxx sata_via sata_sil sata_nv sd_mod ahci atiixp raid0 raid1 raid5 raid6 raid10 3w-xxxx 3w-9xxx aacraid powernow-k8"
export STATSSERVER="127.0.0.1"
export HDDMINSIZE="70000000"

export NAMESERVER=("85.214.20.141" "194.150.168.168" "213.73.91.35" )
export DNSRESOLVER_V6=("2a01:4f8:161:4109::6" "2001:1608:10:195:3:dead:beef:cafe" "2a02:e00:fffd:139::9")
export NTPSERVERS=("0.pool.ntp.org" "1.pool.ntp.org" "2.pool.ntp.org")
export AUTH_DNS1="ns1.first-ns.de"
export AUTH_DNS2="robotns2.second-ns.de"
export AUTH_DNS3="robotns3.second-ns.com"

export DEFAULTPARTS='PART swap swap SWAPSIZE##G\nPART /boot ext3 512M\nPART / ext4 all'
export DEFAULTPARTS_BIG='PART swap swap SWAPSIZE##G\nPART /boot ext3 512M\nPART / ext4 1024G\nPART /home ext4 all'
export DEFAULTPARTS_LARGE='PART swap swap SWAPSIZE##G\nPART /boot ext3 512M\nPART / ext4 2014G\nPART /home ext4 all'
export DEFAULTPARTS_VSERVER="PART / ext3 all"
export DEFAULTPARTS_CLOUDSERVER="PART / ext4 all"
export DEFAULTSWRAID="1"
export DEFAULTTWODRIVESWRAIDLEVEL="1"
export DEFAULTTHREEDRIVESWRAIDLEVEL="5"
export DEFAULTFOURDRIVESWRAIDLEVEL="6"
export DEFAULTLVM="0"
export DEFAULTLOADER="grub"
export DEFAULTGOVERNOR="ondemand"

export V6ONLY="0"

# dialog settings
export DIATITLE="$COMPANY"
export OSMENULIST=(
"Debian"          "(official)"
"Ubuntu"          "(official)"
"CentOS"          "(official)"
"openSUSE"        "(official)"
"Archlinux"       "(!!NO SUPPORT!!)"
"Virtualization"  "(!!NO SUPPORT!!)"
"old images"      "(!!NO SUPPORT!!)"
"custom image"    "(blanco config for user images)"
)

export PROXMOX3_BASE_IMAGE="Debian-79-wheezy-64-minimal"
export PROXMOX4_BASE_IMAGE="Debian-83-jessie-64-minimal"
export PROXMOX5_BASE_IMAGE="Debian-92-stretch-64-minimal"

export RED='\033[1;31m'
export GREEN='\033[1;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export MANGENTA='\033[0;35m'
export CYAN='\033[1;36m'
export GREY='\033[0;37m'
export WHITE='\033[1;39m'
export NOCOL='\033[00m'

# write log entries in debugfile - single line as second argument
debug() {
  line="$*"
  echo "[$(date '+%H:%M:%S')] $line" >> $DEBUGFILE;
}


# write log entries in debugfile - multiple lines at once
debugoutput() {
  while read -r line ; do
    echo "[$(date '+%H:%M:%S')] :   $line" >> $DEBUGFILE;
  done
}

# see https://github.com/koalaman/shellcheck/wiki/SC1090
# because travis uses an older version we need to disable the check completely
# shellcheck disable=SC1090
. "$FUNCTIONSFILE"

# vim: ai:ts=2:sw=2:et
