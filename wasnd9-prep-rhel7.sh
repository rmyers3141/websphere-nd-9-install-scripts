#!/bin/bash
#
################################################################################
#
# NAME:         wasnd9-prep-rhel7.sh
# VERSION:      1.00
# DESCRIPTION:  Script to prepare RHEL 7 platform for installation of IBM
#               WebSphere Application Server (WAS) Network Deployment V9.0.
#
#               The script installs/updates prerequisite .RPMs required prior
#               to the installation of IBM Installation Manager and WAS V9.0.
#               
#               IMPORTANT: This script assumes the server has connection to a
#               valid public or private yum server that contains all the pre-
#               requisite .rpm packages.
#
#
################################################################################
#
#
# BEGIN DECLARE CONSTANTS & ENV VARS
SCRIPTNAME=`basename $0`
#LOG=/var/tmp/${SCRIPTNAME}.log
LOG=/dev/null
export PATH=$PATH:/sbin:/usr/sbin
# END DECLARE CONSTANTS & ENV VARS


# BEGIN FUNCTION DEFINITIONS

# Function to handle premature script termination:
abort() {
  printf "========================================================\n" | tee -a ${LOG}
  printf "ERROR: %s\n" "$1" | tee -a ${LOG}
  printf "SCRIPT ENDED ABNORMALLY ON: %s\n" "`date`" | tee -a ${LOG}
  exit 1
}


# Check if sudo required:
sudo_check() {
  uid=`id | /bin/sed -e 's;^.*uid=;;' -e 's;\([0-9]\)(.*;\1;'`
  if [ "$uid" = "0" ] ; then
    SUDO=" "
  else
    SUDO=`which sudo 2>/dev/null`
    if [ -z "${SUDO}" ] ; then
      abort "SUDO NOT FOUND."
    fi
  fi
}


# Function to install .rpms specified by $1 using yum
pkg_install() {
  if [ "$1" == "" ] ; then
    printf "=> Package name not specified, please specify a package name as first argument.\n\n"  | tee -a ${LOG}
  else
    # Run yum in quiet mode.
    ${SUDO} yum -y -q install "$1"
    if [ "$?" -eq 0 ] ; then
      printf "=> $1 installed, updated, or already up-to-date: PASS.\n"  | tee -a ${LOG}
    else
      abort "$1 failed installation, updating, or checking: FAIL.\n"
    fi
  fi
}


# END FUNCTION DEFINITIONS


########################################################################
# MAIN
########################################################################
# Prerequite checks
########################################################################
#
printf "\nSTARTING SCRIPT ON:\n" | tee ${LOG}
date | tee -a ${LOG}
sudo_check
#
########################################################################
# IBM WAS 9.0 : GENERAL LINUX PREREQUISITE .RPM UPDATES
########################################################################
#
########################################################################
# Kernel and C runtime library
# (only 64-bit installed)
########################################################################

printf "\nKernel and C runtime libraries:\n" | tee -a ${LOG}

pkg_install glibc.x86_64
#pkg_install glibc.i686

pkg_install libgcc.x86_64
#pkg_install libgcc.i686

pkg_install kernel-headers.x86_64

#########################################################################
# Current and all compatibility versions of the C++ runtime library
# (only 64-bit installed)
#########################################################################

printf "\nC++ runtime libraries:\n" | tee -a ${LOG}

pkg_install libstdc++.x86_64
#pkg_install libstdc++.i686

pkg_install compat-libstdc++-33.x86_64
#pkg_install compat-libstdc++-33.i686
#pkg_install compat-libstdc++-296.i686

##########################################################################
# X Windows libraries and runtime
##########################################################################

printf "\nX Windows libraries and runtime group install:\n" | tee -a ${LOG}

pkg_install "@X Window System"

##########################################################################
# GTK runtime libraries
# (only 64-bit installed)
##########################################################################

printf "\nGTK runtime libraries:\n" | tee -a ${LOG}

pkg_install gtk2.x86_64
#pkg_install gtk2.i686

#pkg_install gtk2-engines.x86_64
#pkg_install gtk2-engines.i686 

##########################################################################
# IBM WAS 9.0 : RHEL 7 SPECIFIC PREREQUISITE .RPMs
# (some of these may have been provided already by general Linux prereqs.
#  See above)
##########################################################################

printf "\nRequired .rpms for RHEL 7 platforms:\n" | tee -a ${LOG}

pkg_install gtk2
pkg_install libXtst
pkg_install xorg-x11-fonts-Type1
pkg_install psmisc

##########################################################################
# GENERAL LINUX PREREQUISITES - OTHER
##########################################################################

printf "\nMozilla Firefox:\n" | tee -a ${LOG}

# Install Mozilla Firefox web browser.
pkg_install firefox.x86_64

##########################################################################
# END OF .RPM UPDATES
##########################################################################

printf "\nENDING SCRIPT ON:\n" | tee -a ${LOG}
date | tee -a ${LOG}

exit 0

