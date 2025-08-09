#!/bin/bash
#
################################################################################
#
# NAME:         AppServerPortsProps_wrapper_rhel7.sh
# VERSION:      1.00
# DESCRIPTION:  This script changes the ports (aka "End Points") of a WebSphere
#               Application Server instance. It calls a Jython 2.7-compatible  
#               script called "AppServerPortsProps_J27.py" to make the actual 
#               changes in WebSphere.
#
#               The new port settings are specified below.  The user of this 
#               script can either override the default settings given below by
#               editing the variables defined in the the assign_appsvr_ports() 
#               function, or alter them by specifying an "offset" value which 
#               recalculates the port values by incrementing them by a value 
#               given by the PORT_OFFSET variable. Please avoid using a negative 
#               value for this variable to avoid any potential problems.
#
#               The new port values are then written to a temporary file, 
#               specified by the APPSVR_PORTS_FILE.  This file is subsequently
#               read by the Jython script "AppServerPortsProps.py" which  
#               makes the necessary configuration changes in WebSphere.  The
#               location of this Jython script must be specified using the 
#               JYTHON_SCRIPT variable.
#          
#               Finally, the host machine's firewall ports are opened 
#               inbound according to the new port values. Currently, this
#               script only configures firewalld-based firewalls as found
#               on RHEL7-based platforms.
#                
#               Before running this script, please set the constant and 
#               variable assignments according to your environment:
#               
#               WAS_USER = Unix user that owns and runs WAS.
#               WAS_GROUP = Unix group that owns and runs WAS.
#               WAS_ROOT = Path to the WAS installation.
#               PROFILE_NAME = WAS profile used for admin functions.
#               JYTHON_SCRIPT = Path to AppServerPortsProps_J27.py script.
#               WAS_APPSVR = WAS app server for which ports will be changed.
#               WAS_NODE = Node that WAS_APPSVR resides on.
#               PROFILE_PATH = Path to WAS profile used for admin functions.
#               WAS_ADMIN_USER = WAS admin user with full privileges.
#               WAS_ADMIN_PASSWORD = Password for WAS_ADMIN_USER.
#               APPSVR_PORTS_FILE = Specify where to create temp ports file.
#               PORT_OFFSET = Positive integer value for offsetting port values.
#               WAS_NIC = Network interface used by WAS. NOT REQUIRED.
#               LOG = Log file created by script; set to /dev/null if not
#               required.
#
#               IMPORTANT: For security reasons, some above the above values
#               (such as WAS_ADMIN_PASSWORD) should ideally be defined 
#               externally before running this script. 
#
#               NOTE:  The initial port values (defined under PROFILE PORT 
#               DEFINITIONS below) are based on those of the default WAS app
#               server template, including some incremental adjustments made 
#               for accomodating a Deployment Manager profile on the same
#               host machine.
#
################################################################################
#
#
# BEGIN DECLARE CONSTANTS & ENVIRONMENT VARIABLES
WAS_USER=${WAS_USER:=wbsadm}
WAS_GROUP=${WAS_GROUP:=wbsadm}
WAS_ROOT=${WAS_ROOT:=/apps/IBM/WebSphere/AppServer}
PROFILE_NAME=${PROFILE_NAME:=Dmgr01}
JYTHON_SCRIPT=${JYTHON_SCRIPT:=/scripts/was9/AppServerPortsProps_J27.py}
WAS_APPSVR=${WAS_APPSVR:=server1}
WAS_NODE=${WAS_NODE:=centos70Node01}
PROFILE_PATH=${WAS_ROOT}/profiles/${PROFILE_NAME}
WAS_ADMIN_USER=${WAS_ADMIN_USER:=wasadmin}
WAS_ADMIN_PASSWORD=${WAS_ADMIN_PASSWORD:=12345678}
APPSVR_PORTS_FILE=/tmp/${WAS_APPSVR}.portdef.props
PORT_OFFSET=${PORT_OFFSET:=0}
WAS_NIC=${WAS_NIC:=enp0s3}
SCRIPTNAME=`basename $0`
LOG=/var/tmp/${SCRIPTNAME}.log
export PATH=$PATH:/sbin:/usr/sbin
# END DECLARE CONSTANTS & ENVIRONMENT VARIABLES
#
#
# BEGIN DECLARE DEFAULT PROFILE PORT DEFINITIONS
SOAP_CONNECTOR_ADDRESS=${SOAP_CONNECTOR_ADDRESS:=8880}
SIP_DEFAULTHOST_SECURE=${SIP_DEFAULTHOST_SECURE:=5061}
SIP_DEFAULTHOST=${SIP_DEFAULTHOST:=5060}
SIB_ENDPOINT_ADDRESS=${SIB_ENDPOINT_ADDRESS:=7276}
WC_defaulthost_secure=${WC_defaulthost_secure:=9443}
DCS_UNICAST_ADDRESS=${DCS_UNICAST_ADDRESS:=9353}
SIB_MQ_ENDPOINT_SECURE_ADDRESS=${SIB_MQ_ENDPOINT_SECURE_ADDRESS:=5578}
WC_adminhost_secure=${WC_adminhost_secure:=9044}
CSIV2_SSL_MUTUALAUTH_LISTENER_ADDRESS=${CSIV2_SSL_MUTUALAUTH_LISTENER_ADDRESS:=9406}
ORB_LISTENER_ADDRESS=${ORB_LISTENER_ADDRESS:=9102}
BOOTSTRAP_ADDRESS=${BOOTSTRAP_ADDRESS:=9810}
CSIV2_SSL_SERVERAUTH_LISTENER_ADDRESS=${CSIV2_SSL_SERVERAUTH_LISTENER_ADDRESS:=9405}
IPC_CONNECTOR_ADDRESS=${IPC_CONNECTOR_ADDRESS:=9633}
SIB_ENDPOINT_SECURE_ADDRESS=${SIB_ENDPOINT_SECURE_ADDRESS:=7286}
WC_defaulthost=${WC_defaulthost:=9080}
SIB_MQ_ENDPOINT_ADDRESS=${SIB_MQ_ENDPOINT_ADDRESS:=5558}
OVERLAY_UDP_LISTENER_ADDRESS=${OVERLAY_UDP_LISTENER_ADDRESS:=11007}
SAS_SSL_SERVERAUTH_LISTENER_ADDRESS=${SAS_SSL_SERVERAUTH_LISTENER_ADDRESS:=9404}
OVERLAY_TCP_LISTENER_ADDRESS=${OVERLAY_TCP_LISTENER_ADDRESS:=11008}
WC_adminhost=${WC_adminhost:=9061}
# END DECLARE DEFAULT PROFILE PORT DEFINITIONS
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


# Basic check for installation of WAS.
was_check () {
  if [ ! -d "${WAS_ROOT}" ] ; then
    abort "WAS installation not found, aborting script." 
  else
    printf "=> WAS installation found.\n\n" | tee -a ${LOG}
  fi
}


# Adjust port assignments based on PORT_OFFSET value:
assign_appsvr_ports() {
  SOAP_CONNECTOR_ADDRESS=$(( ${SOAP_CONNECTOR_ADDRESS} + ${PORT_OFFSET} ))
  SIP_DEFAULTHOST_SECURE=$(( ${SIP_DEFAULTHOST_SECURE} + ${PORT_OFFSET} ))
  SIP_DEFAULTHOST=$(( ${SIP_DEFAULTHOST} + ${PORT_OFFSET} ))
  SIB_ENDPOINT_ADDRESS=$(( ${SIB_ENDPOINT_ADDRESS} + ${PORT_OFFSET} ))
  WC_defaulthost_secure=$(( ${WC_defaulthost_secure} + ${PORT_OFFSET} ))
  DCS_UNICAST_ADDRESS=$(( ${DCS_UNICAST_ADDRESS} + ${PORT_OFFSET} ))
  SIB_MQ_ENDPOINT_SECURE_ADDRESS=$(( ${SIB_MQ_ENDPOINT_SECURE_ADDRESS} + ${PORT_OFFSET} ))
  WC_adminhost_secure=$(( ${WC_adminhost_secure}  + ${PORT_OFFSET} ))
  CSIV2_SSL_MUTUALAUTH_LISTENER_ADDRESS=$(( ${CSIV2_SSL_MUTUALAUTH_LISTENER_ADDRESS} + ${PORT_OFFSET} ))
  ORB_LISTENER_ADDRESS=$(( ${ORB_LISTENER_ADDRESS} + ${PORT_OFFSET} ))
  BOOTSTRAP_ADDRESS=$(( ${BOOTSTRAP_ADDRESS} + ${PORT_OFFSET} ))
  CSIV2_SSL_SERVERAUTH_LISTENER_ADDRESS=$(( ${CSIV2_SSL_SERVERAUTH_LISTENER_ADDRESS} + ${PORT_OFFSET} ))
  IPC_CONNECTOR_ADDRESS=$(( ${IPC_CONNECTOR_ADDRESS} + ${PORT_OFFSET} ))
  SIB_ENDPOINT_SECURE_ADDRESS=$(( ${SIB_ENDPOINT_SECURE_ADDRESS} + ${PORT_OFFSET} ))
  WC_defaulthost=$(( ${WC_defaulthost} + ${PORT_OFFSET} ))
  SIB_MQ_ENDPOINT_ADDRESS=$(( ${SIB_MQ_ENDPOINT_ADDRESS} + ${PORT_OFFSET} ))
  OVERLAY_UDP_LISTENER_ADDRESS=$(( ${OVERLAY_UDP_LISTENER_ADDRESS} + ${PORT_OFFSET} ))
  SAS_SSL_SERVERAUTH_LISTENER_ADDRESS=$(( ${SAS_SSL_SERVERAUTH_LISTENER_ADDRESS} + ${PORT_OFFSET} ))
  OVERLAY_TCP_LISTENER_ADDRESS=$(( ${OVERLAY_TCP_LISTENER_ADDRESS} + ${PORT_OFFSET} ))
  WC_adminhost=$(( ${WC_adminhost}  + ${PORT_OFFSET} ))
}


# Create a ports file specified by first argument.
create_ports_file() {
  if [ "$1" == "" ] ; then
    abort "Fully qualified name of ports file not specified, aborting." 
  else
    ${SUDO} touch "$1"
    ${SUDO} chmod 666 "$1"
    ${SUDO} chown ${WAS_USER}:${WAS_GROUP} "$1"
  fi
}


# Populate ports file.
populate_appsvr_ports_file() {

cat > "${APPSVR_PORTS_FILE}" << EOF
SOAP_CONNECTOR_ADDRESS=${SOAP_CONNECTOR_ADDRESS}
SIP_DEFAULTHOST_SECURE=${SIP_DEFAULTHOST_SECURE}
SIP_DEFAULTHOST=${SIP_DEFAULTHOST}
SIB_ENDPOINT_ADDRESS=${SIB_ENDPOINT_ADDRESS}
WC_defaulthost_secure=${WC_defaulthost_secure}
DCS_UNICAST_ADDRESS=${DCS_UNICAST_ADDRESS}
SIB_MQ_ENDPOINT_SECURE_ADDRESS=${SIB_MQ_ENDPOINT_SECURE_ADDRESS}
WC_adminhost_secure=${WC_adminhost_secure}
CSIV2_SSL_MUTUALAUTH_LISTENER_ADDRESS=${CSIV2_SSL_MUTUALAUTH_LISTENER_ADDRESS}
ORB_LISTENER_ADDRESS=${ORB_LISTENER_ADDRESS}
BOOTSTRAP_ADDRESS=${BOOTSTRAP_ADDRESS}
CSIV2_SSL_SERVERAUTH_LISTENER_ADDRESS=${CSIV2_SSL_SERVERAUTH_LISTENER_ADDRESS}
IPC_CONNECTOR_ADDRESS=${IPC_CONNECTOR_ADDRESS}
SIB_ENDPOINT_SECURE_ADDRESS=${SIB_ENDPOINT_SECURE_ADDRESS}
WC_defaulthost=${WC_defaulthost}
SIB_MQ_ENDPOINT_ADDRESS=${SIB_MQ_ENDPOINT_ADDRESS}
OVERLAY_UDP_LISTENER_ADDRESS=${OVERLAY_UDP_LISTENER_ADDRESS}
SAS_SSL_SERVERAUTH_LISTENER_ADDRESS=${SAS_SSL_SERVERAUTH_LISTENER_ADDRESS}
OVERLAY_TCP_LISTENER_ADDRESS=${OVERLAY_TCP_LISTENER_ADDRESS}
WC_adminhost=${WC_adminhost}
EOF

}


# Function to run Jython script to change port values in WAS.
# TO-DO


# Create new firewalld service with name specified by $1.
firewalld_service_create() {
  if [ "$1" == "" ] ; then
    abort "Please specify service name before continuing.\n\n."
  else
    printf "CREATING NEW FIREWALLD SERVICE $1: " | tee -a ${LOG}
    ${SUDO} firewall-cmd --permanent --new-service=$1 | tee -a ${LOG}
    ${SUDO} firewall-cmd --permanent --service=$1 --set-description="Firewall rules for $1" > /dev/null 2>&1 | tee -a ${LOG}
    ${SUDO} firewall-cmd --permanent --service=$1 --set-short=$1 > /dev/null 2>&1 | tee -a ${LOG}
    if [ "$?" -eq 0 ] ; then
      return 0
    else
      abort "FAILED TO CREATE FIREWALLD SERVICE $1."
    fi
  fi
}


# Function to open firewall ports on a firewalld service. It requires three arguments:
# $1 must be the name of the firewalld service, $2 the port number and $3 the protocol.
firewalld_service_port() {
  if [ "$#" == "3" ] ; then
    printf "=> Adding port $2/$3 to firewalld service $1: " | tee -a ${LOG}
    ${SUDO} firewall-cmd --permanent --service=$1 --add-port=$2/$3
    if [ "$?" -ne 0 ] ; then
      printf "ERROR: Failed to add port $2/$3 to firewalld service $1.\n\n" | tee -a ${LOG}
      return 1
    else
      return 0
    fi
  else
    abort "Function is missing required parameters!"
  fi
}


# Post-install cleanup function.
cleanup() {
  if [ -f "${NODE_PORTS_FILE}" ] ; then
    ${SUDO} rm -f "${NODE_PORTS_FILE}"
  fi
}


# END FUNCTION DEFINITIONS

################################################################################
# MAIN
################################################################################
echo STARTING SCRIPT ON: | tee ${LOG}
date | tee -a ${LOG}
echo "============================" | tee -a ${LOG}
echo "" | tee -a ${LOG}

################################################################################


# Preliminary checks:
sudo_check
was_check


# Define ports used by node agent for custom profile:
assign_appsvr_ports
create_ports_file ${APPSVR_PORTS_FILE}
populate_appsvr_ports_file

# Run Jython script to make changes to WAS configuration:
printf "\nBEGIN EXECUTION OF JYTHON SCRIPT ${JYTHON_SCRIPT}: \n\n" | tee -a ${LOG}

${SUDO} su - ${WAS_USER} -c "${PROFILE_PATH}/bin/wsadmin.sh -lang jython -profileName ${PROFILE_NAME} -username ${WAS_ADMIN_USER} -password ${WAS_ADMIN_PASSWORD} -f "${JYTHON_SCRIPT}" --server ${WAS_APPSVR} --node ${WAS_NODE} --newprops "${APPSVR_PORTS_FILE}""  | tee -a ${LOG}

printf "\nENDED EXECUTION OF JYTHON SCRIPT ${JYTHON_SCRIPT}. \n\n" | tee -a ${LOG}


################### Configure firewall service for new profile ##################
# Create new firewalld service:
firewalld_service_create WAS-${WAS_APPSVR}

# Add required ports to firewalld service:
firewalld_service_port WAS-${WAS_APPSVR} ${SOAP_CONNECTOR_ADDRESS} tcp
firewalld_service_port WAS-${WAS_APPSVR} ${SIP_DEFAULTHOST_SECURE} tcp
firewalld_service_port WAS-${WAS_APPSVR} ${SIP_DEFAULTHOST} tcp
firewalld_service_port WAS-${WAS_APPSVR} ${SIB_ENDPOINT_ADDRESS} tcp
firewalld_service_port WAS-${WAS_APPSVR} ${WC_defaulthost_secure} tcp
firewalld_service_port WAS-${WAS_APPSVR} ${DCS_UNICAST_ADDRESS} tcp
firewalld_service_port WAS-${WAS_APPSVR} ${SIB_MQ_ENDPOINT_SECURE_ADDRESS} tcp
firewalld_service_port WAS-${WAS_APPSVR} ${WC_adminhost_secure} tcp
firewalld_service_port WAS-${WAS_APPSVR} ${CSIV2_SSL_MUTUALAUTH_LISTENER_ADDRESS} tcp
firewalld_service_port WAS-${WAS_APPSVR} ${ORB_LISTENER_ADDRESS} tcp
firewalld_service_port WAS-${WAS_APPSVR} ${BOOTSTRAP_ADDRESS} tcp
firewalld_service_port WAS-${WAS_APPSVR} ${CSIV2_SSL_SERVERAUTH_LISTENER_ADDRESS} tcp
firewalld_service_port WAS-${WAS_APPSVR} ${IPC_CONNECTOR_ADDRESS} tcp
firewalld_service_port WAS-${WAS_APPSVR} ${SIB_ENDPOINT_SECURE_ADDRESS} tcp
firewalld_service_port WAS-${WAS_APPSVR} ${WC_defaulthost} tcp
firewalld_service_port WAS-${WAS_APPSVR} ${SIB_MQ_ENDPOINT_ADDRESS} tcp
firewalld_service_port WAS-${WAS_APPSVR} ${OVERLAY_UDP_LISTENER_ADDRESS} udp
firewalld_service_port WAS-${WAS_APPSVR} ${SAS_SSL_SERVERAUTH_LISTENER_ADDRESS} tcp
firewalld_service_port WAS-${WAS_APPSVR} ${OVERLAY_TCP_LISTENER_ADDRESS} tcp
firewalld_service_port WAS-${WAS_APPSVR} ${WC_adminhost} tcp

# Add service to the public zone:
printf "\n=> Adding service to public zone: " | tee -a ${LOG}
${SUDO} firewall-cmd --permanent --zone=public --add-service=WAS-${WAS_APPSVR}

# Reload firewall:
printf "\n=> Reloading firewalld: " | tee -a ${LOG}
${SUDO} firewall-cmd --reload

################################################################################


# Remove temporary files used for profile creation:
cleanup


################################################################################

echo "============================" | tee -a ${LOG}
echo ENDING SCRIPT ON: | tee -a ${LOG}
date | tee -a ${LOG}

exit 0
