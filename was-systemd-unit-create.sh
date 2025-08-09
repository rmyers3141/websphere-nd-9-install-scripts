#!/bin/bash
#
################################################################################
#
# NAME:         was-systemd-unit-create.sh
# VERSION:      1.00
# DESCRIPTION:  Creates systemd services for WebSphere 
#               Application Server (WAS) instances on Red Hat Enterprise 
#               Linux 7 (RHEL7).
#
#               Creates systemd unit files for either Deployment Manager, 
#               Node Agent, or Application Server processes. Before running this  
#               script, the user must specify which of these to create by 
#               ensuring the WAS_TYPE is set appropriately to either:
#
#               DeploymentManager
#               NodeAgent
#               AppServer
#
#               It will then create service names 'was-dmgr', 'was-nodeagent' or  
#               'was_appsvr' (where 'appsvr' is the name of the particular WAS 
#               app server instance), and add them for service management by 
#               systemd.
#
#               Please ensure other variables are set appropriate for the 
#               environment before running this script, particularly:  
#               PROFILE_PATH, WAS_JVM (when WAS_TYPE=AppServer), WAS_USER. 
#               Suggested default values for all constants and variables are 
#               given throughout this script.
#
#               NOTE: The systemd unit files created do not use internal WAS 
#               usernames/passwords for the 'stop' and 'status' commands.  This 
#               is because these are assumed to be already securely embedded 
#               in the soap.client.props file for each profile.  If this is not
#               the case, please ensure this is done first, otherwise this script 
#               will need to be modified to embed the necessary username/password 
#               information.  But please bear in mind that the latter can be 
#               considered insecure.
#
#               CAVEAT:  Use of the systemd unit files can be problematic as WAS
#               processes can be managed independently of systemd.
#               Please therefore review carefully whether they are appropriate 
#               for your environment and adjust your operational procedures 
#               accordingly.
#
################################################################################
#
#
#
# BEGIN DECLARE CONSTANTS & ENVIRONMENT VARIABLES
WAS_USER=${WAS_USER:=wbsadm}
WAS_TYPE=${WAS_TYPE:=AppServer}
SCRIPTNAME=`basename $0`
#LOG=/var/tmp/${SCRIPTNAME}.log
LOG=/dev/null
export PATH=$PATH:/sbin:/usr/sbin
# END DECLARE CONSTANTS & ENVIRONMENT VARIABLES
#
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


# Function to create systemd unit file for WAS process.
# NOTE: Each service is given a timeout of 300 seconds
# to start and stop.
was_systemd_unit_create() {
#
${SUDO} touch /etc/systemd/system/${WAS_SERVICE}.service
${SUDO} chmod 664 /etc/systemd/system/${WAS_SERVICE}.service
#
${SUDO} cat > /etc/systemd/system/${WAS_SERVICE}.service << EOF
[Unit]
Description=WebSphere Application Server (WAS) ${WAS_DESC}.
After=network.target remote-fs.target nss-lookup.target ${WAS_DEPENDENCY}

[Service]
Type=forking
ExecStart=${PROFILE_PATH}/bin/${STARTCMD}
ExecStop=${PROFILE_PATH}/bin/${STOPCMD}
User=${WAS_USER}
PIDFile=${PROFILE_PATH}/logs/${WAS_JVM}/${WAS_JVM}.pid
TimeoutSec=300

[Install]
WantedBy=default.target
EOF
#
#
${SUDO} systemctl daemon-reload
${SUDO} systemctl enable ${WAS_SERVICE}.service
if [ "$?" -eq 0 ] ; then
  printf "\n\n=> WAS SYSTEMD SERVICE ${WAS_SERVICE}.service CREATED SUCCESSFULLY.\n\n" | tee -a ${LOG}
else
  abort "A PROBLEM OCCURRED CREATING THE SYSTEMD SERVICE, ${WAS_SERVICE}.service."
fi

}

#### MAIN ####
 
sudo_check

case "${WAS_TYPE}" in
  DeploymentManager)
    # Specify Deployment Manager specific settings here:
    PROFILE_PATH=${PROFILE_PATH:=/apps/IBM/WebSphere/AppServer/profiles/Dmgr01}
    WAS_JVM=${WAS_JVM:=dmgr}
    WAS_SERVICE=was-${WAS_JVM}
    WAS_DESC="Deployment Manager"
    WAS_DEPENDENCY=""
    STARTCMD=startManager.sh
    STOPCMD=stopManager.sh
    # Execute function:
    was_systemd_unit_create
    ;;
  NodeAgent)
    # Specify Node Agent specific settings here:
    PROFILE_PATH=${PROFILE_PATH:=/apps/IBM/WebSphere/AppServer/profiles/AppSrv01}
    WAS_JVM=${WAS_JVM:=nodeagent}
    WAS_SERVICE=was-${WAS_JVM}
    WAS_DESC="Node Agent"
    WAS_DEPENDENCY=""
    STARTCMD=startNode.sh
    STOPCMD=stopNode.sh
    # Execute function:
    was_systemd_unit_create
    ;;
  AppServer)
    # Specify Application Server specific settings here:
    PROFILE_PATH=${PROFILE_PATH:=/apps/IBM/WebSphere/AppServer/profiles/AppSrv01}
    WAS_JVM=${WAS_JVM:=server1}
    WAS_SERVICE=was-${WAS_JVM}
    WAS_DESC="app server ${WAS_JVM}"
    WAS_DEPENDENCY=was-nodeagent.service
    STARTCMD="startServer.sh ${WAS_JVM}"
    STOPCMD="stopServer.sh ${WAS_JVM}"
    # Execute function:
    was_systemd_unit_create
    ;;
  *)
    abort "WAS_TYPE not correctly set."
esac

exit 0

