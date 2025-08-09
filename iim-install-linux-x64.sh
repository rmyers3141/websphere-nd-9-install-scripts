#!/bin/bash
#
################################################################################
#
# NAME:         iim-install-linux-x64.sh
# VERSION:      1.00
# DESCRIPTION:  Script to silently install IBM Installation Manager (IIM)
#               on Linux x64 platforms. 
#
#               The preferred installation mode is non-Administrator (nonAdmin)
#               and this script creates a specific user and group for that
#               purpose.  However, the script can also install IIM in 
#               Administrator (Admin) or Group (Group) mode, if required, by
#               changing the value of the constant IIM_MODE. 
#
#               Group mode is not recommended as it has limitations.
#               
#               Ideally, the user that IIM is installed as should be the same
#               user you intended to run WebSphere Application Server (WAS) as.
#
#
################################################################################
#
#
# BEGIN DECLARE CONSTANTS & ENV VARS
IIM_GROUP=${IIM_GROUP:=wbsadm}
IIM_USER=${IIM_USER:=wbsadm}
IIM_SHELL=${IIM_SHELL:=/bin/bash}
IIM_PARENT=${IIM_PARENT:=/apps/IBM}
IIM_MEDIA=${IIM_MEDIA:=/kits/IBM/iim/agent.installer.linux.gtk.x86_64_1.8.8000.20171130_1105.zip}
IIM_PACKAGE=${IIM_PACKAGE:=com.ibm.cic.agent_1.8.8000.20171130_1105}
IIM_MODE=${IIM_MODE:=nonAdmin}
IIM_INSTALL_LOG=${IIM_INSTALL_LOG:=/var/tmp/InstallationManager_install_log.xml}
SCRIPTNAME=`basename $0`
#LOG=/var/tmp/${SCRIPTNAME}.log
LOG=/dev/null
export PATH=$PATH:/sbin:/usr/sbin
# END DECLARE CONSTANTS & ENV VARS
#
#
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


# Ensure IIM group exists:
group_check() {
  if ${SUDO} getent group "${IIM_GROUP}" > /dev/null 2>&1
  then
    printf "=> Group ${IIM_GROUP} exists.\n\n"  | tee -a ${LOG}
  else
    printf "Group ${IIM_GROUP} does not exist yet, adding group...\n\n"  | tee -a ${LOG}
    ${SUDO} groupadd "${IIM_GROUP}" ||
    abort "Problem creating ${IIM_GROUP} group."
    printf "=> Group ${IIM_GROUP} added.\n\n"  | tee -a ${LOG}
  fi
}


# Ensure IIM user exists:
user_check() {
  if ${SUDO} getent passwd ${IIM_USER} > /dev/null 2>&1
  then
    printf "=> User ${IIM_USER} exists.\n\n" | tee -a ${LOG}
  else
    printf "User ${IIM_USER} does not exist yet, adding user...\n\n"  | tee -a ${LOG}
    ${SUDO} useradd -g ${IIM_GROUP} -s ${IIM_SHELL} ${IIM_USER} ||
    abort "Problem creating ${IIM_USER} user."
    printf "=> User ${IIM_USER} added.\n\n"  | tee -a ${LOG}
  fi
}


# Define any desired properties for IIM user here - umask 0002 needed for Group mode.
user_settings() {
  # First determine home directory of IIM user.
  IIM_HOME=`getent passwd ${IIM_USER} | cut -d : -f 6`
  # Set preferred umask of 0002 for Group mode installations:
  if [ -d "${IIM_HOME}" -a "${IIM_MODE}" = "Group" ] ; then
    echo "umask 0002" | ${SUDO} tee -a "${IIM_HOME}/.bashrc"
    printf "=> User settings updated.\n\n" | tee -a ${LOG}
  else
    abort "User settings not updated.\n\n"
  fi
}


# Check for existence of parent holding directory & assign permissions.
parent_dir() {
  if [ ! -d "${IIM_PARENT}" ] ; then
    ${SUDO} mkdir -p "${IIM_PARENT}"
    ${SUDO} chown -R ${IIM_USER}:${IIM_GROUP} "${IIM_PARENT}"
  fi
}


# Create IIM agent data location directory - needed for Group mode only.
agent_data() {
  if [ -z "${IIM_DATA}" ] ; then
    abort "IIM_DATA variable not defined, aborting...\n\n"
  else
    if [ -d "${IIM_DATA}" ] ; then
      abort "${IIM_DATA} already exists, aborting...\n\n"
    else
      ${SUDO} mkdir -p -m 0775 "${IIM_DATA}"
      ${SUDO} chown -R ${IIM_USER}:${IIM_GROUP} "${IIM_DATA}"
    fi
  fi
}


# Extract IIM installation kit to temporary holding directory & assign permissions.
media_prepare() {
  if [ -d /tmp/IIM_kit ] ; then
    ${SUDO} rm -rf /tmp/IIM_kit/*
  else
    ${SUDO} mkdir -p /tmp/IIM_kit
  fi
  ${SUDO} unzip "${IIM_MEDIA}" -d /tmp/IIM_kit > /dev/null
  ${SUDO} chown -R ${IIM_USER}:${IIM_GROUP} /tmp/IIM_kit
}


# Post-install cleanup function.
cleanup() {
  if [ -d /tmp/IIM_kit ] ; then
    ${SUDO} rm -rf /tmp/IIM_kit
  fi
}


# Function to install .rpms specified by $1 using yum
pkg_install() {
  if [ "$1" == "" ] ; then
    printf "=> Package name not specified, please specify a package name as first argument.\n\n"  | tee -a ${LOG}
  else
    # Run yum in quiet mode.
    ${SUDO} yum -y -q install "$1"
    # Run yum in non-quiet mode.
    # ${SUDO} yum -y install "$1"
    if [ "$?" -eq 0 ] ; then
      printf "=> $1 installed, updated, or already up-to-date: PASS.\n"  | tee -a ${LOG}
    else
      abort "$1 failed installation, updating, or checking: FAIL.\n"  | tee -a ${LOG}
    fi
  fi
}


# Install in Admin mode, silently.
install_admin() {
  printf "Installing in Administrator mode...\n\n"  | tee -a ${LOG}
  ${SUDO} /tmp/IIM_kit/installc -installationDirectory ${IIM_PARENT}/InstallationManager -log ${IIM_INSTALL_LOG} -acceptLicense -showProgress
  if [ "$?" -eq 0 ] ; then
    printf "\n=> Installation completed.\n\n" | tee -a ${LOG}
    cleanup
    return 0
  else
    cleanup
    abort "A problem may have occurred during installation, aborting...\n\n"
  fi
}


# Install in nonAdmin mode, silently.
install_nonadmin() {
  printf "Installing in non-Administrator mode for user ${IIM_USER}...\n\n"  | tee -a ${LOG}
  ${SUDO} su - ${IIM_USER} -c "/tmp/IIM_kit/userinstc -installationDirectory ${IIM_PARENT}/InstallationManager -log ${IIM_INSTALL_LOG} -acceptLicense -showProgress"
  if [ "$?" -eq 0 ] ; then
    printf "\n=> Installation completed.\n\n" | tee -a ${LOG}
    cleanup
    return 0
  else
    cleanup
    abort "A problem may have occurred during installation, aborting...\n\n"
  fi
}


# Install in Group mode, silently.
install_group() {
  printf "Installing in Group mode for group ${IIM_GROUP}...\n\n"  | tee -a ${LOG}
  ${SUDO} su - ${IIM_USER} -c "/tmp/IIM_kit/groupinstc -dataLocation ${IIM_DATA} -installationDirectory ${IIM_PARENT}/InstallationManager -log ${IIM_INSTALL_LOG} -acceptLicense -showProgress"
  if [ "$?" -eq 0 ] ; then
    printf "\n=> Installation completed.\n\n" | tee -a ${LOG}
    cleanup
    return 0
  else
    cleanup
    abort "A problem may have occurred during installation, aborting...\n\n" 
 fi
}


# Post-install, basic check.
install_check() {
  ${SUDO} su - ${IIM_USER} -c "${IIM_PARENT}/InstallationManager/eclipse/tools/imcl listInstalledPackages" | grep "${IIM_PACKAGE}" > /dev/null 2>&1
  if [ "$?" -eq 0 ] ; then
    printf "=> Installation appears to have been successful.\n\n" | tee -a ${LOG}
    return 0
  else
    printf  "=> A problem may have occurred with the installation.\n\n" | tee -a ${LOG}
    return 1
  fi
}


# END FUNCTION DEFINITIONS

###############################################################################
# MAIN
################################################################################
# Prerequite Checks & Preparation
################################################################################

printf "\nSTARTING SCRIPT ON:\n" | tee ${LOG}
date | tee -a ${LOG}
printf "\n"
sudo_check

# Install RealVNC vnc-server-4.0-12.el4_7.1 to support remote access for IIM.
# TBD
#pkg_install vnc-server-4.0-12.el4_7.1


################################################################################
# Installation: Admin, nonAdmin or Group mode
################################################################################

case "${IIM_MODE}" in
    Admin)
        IIM_GROUP=root
        IIM_USER=root
        parent_dir
        media_prepare
        install_admin
        install_check
        ;;
    nonAdmin)
        group_check
        user_check
        parent_dir
        media_prepare
        install_nonadmin
        install_check
        ;;
    Group)
        # First specify IIM agent data location for Group mode:
        IIM_DATA=/apps/var/ibm/InstallationManager_Group
        group_check
        user_check
        user_settings
        agent_data
        parent_dir
        media_prepare        
        install_group
        install_check
        ;;
    *)
        printf "Please first set IIM_MODE constant to either:\n"
        printf "Admin, nonAdmin or Group before running this script.\n\n"
        abort
esac

printf "\nENDING SCRIPT ON:\n" | tee -a ${LOG}
date | tee -a ${LOG}

