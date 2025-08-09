#!/bin/bash
#
################################################################################
#
# NAME:         wasnd9-install-rhel7.sh
# VERSION:      1.00
# DESCRIPTION:	Script to silently install IBM WebSphere Application Server
#               Network Deployment 9.0 binaries on RHEL 7.x platform.
#               Also includes necessary preparation of the platform prior to 
#               installation. It is recommended to install WAS in nonAdmin mode
#               and to run WAS as the same user that owns and runs IBM 
#               Installation Manager (IIM).
#
#               Note: This script uses an private web-based IIM repository.
#               This must be set up beforehand and it's address be resolvable
#               from the target machine.  The repository uses SSL with a non-
#               signed certificate and requires authentication using
#               credentials stored in the secure storage file specified by the
#               the IIM_SECURE_STORAGE constant.  This must be used in 
#               conjunction withe the master password file specified by the
#               IIM_MASTER constant.
#
################################################################################
#
#
# BEGIN DECLARE CONSTANTS & ENV VARS
IIM_PATH=${IIM_PATH:=/apps/IBM/InstallationManager}
IIM_MODE=${IIM_MODE:=nonAdmin}
IIM_GROUP=${IIM_GROUP:=wbsadm}
IIM_USER=${IIM_USER:=wbsadm}
IIM_MASTER=${IIM_MASTER:=/scripts/was9/master_password.txt}
IIM_SECURE_STORAGE:=${IIM_SECURE_STORAGE:=/scripts/was9/credential.store}
WAS_GROUP=${IIM_GROUP}
WAS_USER=${IIM_USER}
WAS_SHELL=${WAS_SHELL:=/bin/bash}
WAS_FILES_SOFT=${WAS_FILES_SOFT:=8192}
WAS_FILES_HARD=${WAS_FILES_HARD:=16384}
WAS_CORE_SOFT=${WAS_CORE_SOFT:=unlimited}
WAS_CORE_HARD=${WAS_CORE_HARD:=unlimited}
WAS_FS=${WAS_FS:=/apps}
WAS_SPACE=${WAS_SPACE:=2}
WAS_NIC=${WAS_NIC:=enp0s3}
WAS_REPO=${WAS_REPO:=https://repo.iim.test/repo/composite/}
WAS_PKGID=${WAS_PKGID:=com.ibm.websphere.ND.v90_9.0.4.20170523_1327}
SDK_PKGID=${SDK_PKGID:=com.ibm.java.jdk.v8_8.0.4070.20170629_1222}
WAS_ROOT=${WAS_ROOT:=/apps/IBM/WebSphere/AppServer}
WAS_RESPONSE=${WAS_RESPONSE:=/scripts/was9/was9nd-sdk8_install_response_v1.01.xml}
WAS_LOG=${WAS_LOG:=/var/tmp/was9-install_log.xml}
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


# Ensure valid entry exists in /etc/hosts
hosts_check() {
  # Backup /etc/hosts file:
  ${SUDO} /bin/cp -p /etc/hosts /etc/hosts.`date +%F_%H_%M_%S`
  # First remove any possible hostname mappings to loopback addresses:
  hostName=`hostname`
  ${SUDO} sed -i -e "/^127/ s/${hostName}//g" /etc/hosts
  ${SUDO} sed -i -e "/^::1/ s/${hostName}//g" /etc/hosts
  # Add entry after any detected loopback addresses, else beginning of file:
  ip4Address=`ip -4 -o addr show ${WAS_NIC} | awk '{print $4}' | cut -d/ -f1`
  if grep ^::1 /etc/hosts > /dev/null 2>&1 
  then
    ${SUDO} sed -i -e "/^::1/ a ${ip4Address} ${hostName}" /etc/hosts
  else
    if grep ^127 /etc/hosts > /dev/null 2>&1
    then
      ${SUDO} sed -i -e "/^127/ a ${ip4Address} ${hostName}" /etc/hosts
    else
      ${SUDO} sed -i -e "1s/^/${ip4Address} ${hostName}\n/" /etc/hosts
    fi
  fi
}


# Check default shell is /bin/bash.
shell_check() {
  if readlink /bin/sh | grep ^bash$ > /dev/null 2>&1
  then
    printf "=> Default shell is bash.\n\n"  | tee -a ${LOG}
  else
    abort "Default shell is not bash.\n\n"
  fi
}


# Check target filesystem exists and has sufficient free space.
fs_check() {
  if [ ! -d "${WAS_FS}" ]
  then
    abort "Required filesystem ${WAS_FS} is missing.\n\n"
  else
    printf "=> Required filesystem ${WAS_FS} exists.\n\n"  | tee -a ${LOG}	
    # Determine free disk space in GB:
    dfLines=`df -h ${WAS_FS} | wc -l`
    freeFS=`df -h ${WAS_FS} | sed -n ${dfLines}p | awk '{ print $3 }' | sed 's/G//g'`
    if [ `expr "${freeFS}" \>= "${WAS_SPACE}"` == "1" ]
    then
      printf "=> Sufficient free disk space ${freeFS}GB exists on ${WAS_FS}.\n\n"  | tee -a ${LOG}
    else
      abort "Insufficient free disk space ${freeFS}GB exists on ${WAS_FS}.\n\n"
    fi
  fi
}


# Check valid copy command is available in PATH.
cp_check () {
  # Run check as the user that will be performing the installation:
  if ${SUDO} su - ${IIM_USER} -c 'which cp | grep "/bin/cp"'  > /dev/null 2>&1
  then
    printf "=> Correct system copy command cp in PATH\n\n"  | tee -a ${LOG}
  else
    abort "Incorrect system copy command cp in PATH.\n\n"
  fi
}


# Ensure WAS group exists.
group_check() {
  if ${SUDO} getent group "${WAS_GROUP}" > /dev/null 2>&1
  then
    printf "=> Group ${WAS_GROUP} exists.\n\n"  | tee -a ${LOG}
  else
    printf "=> Group ${WAS_GROUP} does not exist yet, adding group...\n\n"  | tee -a ${LOG}
    ${SUDO} groupadd "${WAS_GROUP}" &&
    printf "=> Group ${WAS_GROUP} added.\n\n"  | tee -a ${LOG} 
  fi
}


# Ensure WAS user exists.
user_check() {
  if ${SUDO} getent passwd ${WAS_USER} > /dev/null 2>&1
  then
    printf "=> User ${WAS_USER} exists.\n\n" | tee -a ${LOG}
  else
    printf "=> User ${WAS_USER} does not exist yet, adding user...\n\n"  | tee -a ${LOG}
    ${SUDO} useradd -g ${WAS_GROUP} -s ${WAS_SHELL} ${WAS_USER} &&
    printf "=> User ${WAS_USER} added.\n\n"  | tee -a ${LOG} 
  fi
}


# Define properties for WAS user.
user_settings() {
  # First determine home directory of WAS user.
  WAS_HOME=`getent passwd ${WAS_USER} | cut -d : -f 6`
  if [ -d "${WAS_HOME}" ]
  then
    # Set recommended umask 022, except for IIM Group mode:
    if [ ! ${IIM_MODE} = "Group" ] ; then
      echo "umask 022" | ${SUDO} tee -a "${WAS_HOME}/.bashrc"
    fi
    # Define Firefox browser location if exists:
    if [ -f /usr/bin/firefox ] ; then
      echo "export BROWSER=/usr/bin/firefox" | ${SUDO} tee -a "${WAS_HOME}/.bashrc"
    fi
    # Set recommended resource limits for user:
    ${SUDO} sed -i -e "/End of file/ i ${WAS_USER} soft nofile ${WAS_FILES_SOFT}" /etc/security/limits.conf
    ${SUDO} sed -i -e "/End of file/ i ${WAS_USER} hard nofile ${WAS_FILES_HARD}" /etc/security/limits.conf
    ${SUDO} sed -i -e "/End of file/ i ${WAS_USER} soft core ${WAS_CORE_SOFT}" /etc/security/limits.conf
    ${SUDO} sed -i -e "/End of file/ i ${WAS_USER} hard core ${WAS_CORE_HARD}" /etc/security/limits.conf
    printf "=> WAS user settings updated.\n\n" | tee -a ${LOG}
  else
    abort "WAS user home directory not found.\n\n"
  fi
}


# Grant permissions for non-root installers to create menu entries in Gnome and KDE.
xdgmenus_set() {
  if [ -d "/etc/xdg/menus/applications-merged" ]
  then
    printf "=> xdg menus directory found, granting permissions.\n\n" | tee -a ${LOG}
    ${SUDO} chmod -R 777 /etc/xdg/menus/applications-merged
  else
    printf "=> No xdg menu directory found.\n\n" | tee -a ${LOG}
  fi
}


# Restore original permissions on Gnome and KDE menu entries.
xdgmenus_reset() {
  if [ -d "/etc/xdg/menus/applications-merged" ]
  then
    printf "=> xdg menus directory found, restoring original permissions.\n\n" | tee -a ${LOG}
    ${SUDO} chmod -R 755 /etc/xdg/menus/applications-merged
  else
    printf "=> No xdg menu directory found.\n\n" | tee -a ${LOG}
  fi
}


# Check package (specified by $1) is available for installation from IIM Repository WAS_REPO:
repo_check() {
  if [ "$1" == "" ] ; then
    printf "ERROR: Package name not specified, please specify a package name as first argument.\n\n"  | tee -a ${LOG}
    #return 1
  else
    ${SUDO} su - ${IIM_USER} -c \
    "${IIM_PATH}/eclipse/tools/imcl listAvailablePackages -repositories ${WAS_REPO} -secureStorageFile ${IIM_SECURE_STORAGE} -masterPasswordFile ${IIM_MASTER} -preferences com.ibm.cic.common.core.preferences.ssl.nonsecureMode=true | grep $1" > /dev/null 2>&1
    if [ "$?" -eq 0 ] ; then
      printf "=> Package $1 available.\n\n" | tee -a ${LOG}
      #return 0
    else
      abort "Package $1 not found, installation cannot proceed. Aborting.\n\n"
    fi
  fi
}


# Function to create parent installation directory.
parent_dir() {
  if [ -d "${WAS_ROOT}" ]
  then
    abort "Installation directory ${WAS_ROOT} already exists, exiting.\n\n"
  else
    parentDir=`dirname "${WAS_ROOT}"`
    if [ ${IIM_MODE} = "Group" ] ; then
      ${SUDO} mkdir -p -m 0775 "${parentDir}"
    else
      ${SUDO} mkdir -p -m 0755 "${parentDir}"
    fi
    ${SUDO} chown -R ${WAS_USER}:${WAS_GROUP} "${parentDir}"
    printf "=> Parent directory ${parentDir} created.\n\n" | tee -a ${LOG}
  fi
}


# Function to install WAS in Admin mode.
wasinstall_admin() {
  if [ -f "${WAS_RESPONSE}" ] ; then
    ${SUDO} ${IIM_PATH}/eclipse/tools/imcl -acceptLicense input ${WAS_RESPONSE} -secureStorageFile ${IIM_SECURE_STORAGE} -masterPasswordFile ${IIM_MASTER} -log ${WAS_LOG} -showProgress -variables wasRepo=${WAS_REPO},wasPath=${WAS_ROOT}
    if [ "$?" -eq 0 ]
    then
      printf "\n=> Installation of WAS binaries completed.\n\n" | tee -a ${LOG}
    else
      printf "\n=> ERROR A problem occurred with the installation.\n\n" | tee -a ${LOG}
    fi
  else
    abort "Response file ${WAS_RESPONSE} not found.\n\n"
  fi
}


# Function to install WAS in nonAdmin mode.
wasinstall_nonadmin() {
  if [ -f "${WAS_RESPONSE}" ]
  then
    ${SUDO} su - ${IIM_USER} -c \
    "${IIM_PATH}/eclipse/tools/imcl -acceptLicense input ${WAS_RESPONSE} -secureStorageFile ${IIM_SECURE_STORAGE} -masterPasswordFile ${IIM_MASTER} -log ${WAS_LOG} -showProgress -variables wasRepo=${WAS_REPO},wasPath=${WAS_ROOT}"
    if [ "$?" -eq 0 ]
    then
      printf "\n=> Installation of WAS binaries completed.\n\n" | tee -a ${LOG}
    else
      printf "\n=> ERROR A problem occurred with the installation.\n\n" | tee -a ${LOG}
    fi
  else
    abort "Response file ${WAS_RESPONSE} not found.\n\n"
  fi
}


# Function to install WAS in nonAdmin mode.
wasinstall_group() {
  if [ -f "${WAS_RESPONSE}" ]
  then
    ${SUDO} su - ${IIM_USER} -c \
    "${IIM_PATH}/eclipse/tools/imcl -acceptLicense input ${WAS_RESPONSE} -secureStorageFile ${IIM_SECURE_STORAGE} -masterPasswordFile ${IIM_MASTER} -log ${WAS_LOG} -showProgress -variables wasRepo=${WAS_REPO},wasPath=${WAS_ROOT}"
    if [ "$?" -eq 0 ]
    then
      printf "\n=> Installation of WAS binaries completed.\n\n" | tee -a ${LOG}
    else
      printf "\n=> ERROR A problem occurred with the installation.\n\n" | tee -a ${LOG}
    fi
  else
    abort "Response file ${WAS_RESPONSE} not found.\n\n"
  fi
}


# Verify installation of package (as specified by the first argument $1).
package_check() {
  if [ "$1" == "" ] ; then
    printf "ERROR: Package name not specified, please specify a package name as first argument.\n\n"  | tee -a ${LOG}
    #return 1
  else
    ${SUDO} su - ${IIM_USER} -c \
    "${IIM_PATH}/eclipse/tools/imcl listInstalledPackages | grep $1" > /dev/null 2>&1
    if [ "$?" -eq 0 ] ; then
      printf "=> Package $1 installed successfully.\n\n" | tee -a ${LOG}
      #return 0
    else
      printf "=> ERROR Package $1 not installed.\n\n" | tee -a ${LOG}
      #return 2
    fi
  fi
}


# Placeholder: for function to run chutils if required in the future.
#was_chutils() {
#
#}


## Placeholder: Update SDK JCE to Unlimited Strength Jurisdiction Policy Files.
#sdk_jce() {
  # TBD.
#}


# END FUNCTION DEFINITIONS


################################################################################
# MAIN
################################################################################

echo STARTING SCRIPT ON: | tee ${LOG}
date | tee -a ${LOG}
echo "============================" | tee -a ${LOG}
echo "" | tee -a ${LOG}

################################################################################
# Prerequite Checks & Preparation
################################################################################

sudo_check
fs_check
shell_check
hosts_check

################################################################################
# Installation
################################################################################

case "${IIM_MODE}" in
  Admin)
    IIM_GROUP=root
    IIM_USER=root
    WAS_GROUP=${IIM_GROUP}
    WAS_USER=${IIM_USER}
    user_settings
    cp_check
    repo_check ${WAS_PKGID}
    repo_check ${SDK_PKGID}
    xdgmenus_set
    parent_dir
    wasinstall_admin
    package_check ${WAS_PKGID}
    package_check ${SDK_PKGID}
    ;;
  nonAdmin)
    group_check
    user_check
    user_settings
    cp_check
    repo_check ${WAS_PKGID}
    repo_check ${SDK_PKGID}
    xdgmenus_set
    parent_dir
    wasinstall_nonadmin
    package_check ${WAS_PKGID}
    package_check ${SDK_PKGID}
    ;;
  Group)
    group_check
    user_check
    user_settings
    cp_check
    repo_check ${WAS_PKGID}
    repo_check ${SDK_PKGID}
    xdgmenus_set
    parent_dir
    wasinstall_group
    package_check ${WAS_PKGID}
    package_check ${SDK_PKGID}
    ;;
  *)
    printf "Please first set IIM_MODE constant to either:\n"
    printf "Admin, nonAdmin or Group before running this script.\n\n"
    abort
esac

################################################################################
# Post-Installation Tasks
################################################################################

#was_chutils
xdgmenus_reset

################################################################################

echo "============================" | tee -a ${LOG}
echo ENDING SCRIPT ON: | tee -a ${LOG}
date | tee -a ${LOG}

exit 0

