#!/bin/bash
#
################################################################################
#
# NAME:         wasnd9-profile-dmgr-rhel7.sh
# VERSION:      1.00
# DESCRIPTION:  Script to create a Deployment Manager profile for a WAS 9
#               installation on a RHEL7-based platform as the basis for a new
#               Network Deployment cell.  The constants and port definitions 
#               defined at the beginning of this script allow for a high degree
#               of customisation of the profile.
#               Note: This script assumes that WAS has been installed in the
#               directory specified by WAS_ROOT and is owned by a user defined
#               by the WAS_USER constant and group defined by the WAS_GROUP
#               constant.  Please verify these first before running the script.
#
#
################################################################################
#
#
# BEGIN DECLARE CONSTANTS & ENVIRONMENT VARIABLES
WAS_USER=${WAS_USER:=wbsadm}
WAS_GROUP=${WAS_GROUP:=wbsadm}
WAS_ROOT=${WAS_ROOT:=/apps/IBM/WebSphere/AppServer}
PROFILE_TEMPLATE=${WAS_ROOT}/profileTemplates/management
PROFILE_TYPE=${PROFILE_TYPE:=DEPLOYMENT_MANAGER}
PROFILE_NAME=${PROFILE_NAME:=Dmgr01}
PROFILE_PATH=${WAS_ROOT}/profiles/${PROFILE_NAME}
CELL_NAME=${CELL_NAME:=Cell01}
HOSTNAME=`hostname`
NODE_NAME=${HOSTNAME}CellManager01
SERVER_NAME=${SERVER_NAME:=dmgr}
ADMIN_USER=${ADMIN_USER:=wasadmin}
ADMIN_PASSWORD=${ADMIN_PASSWORD:=12345678}
ORG_NAME=${ORG_NAME:=testcompany}
ORG_COUNTRY=${ORG_COUNTRY:=GB}
PERSONAL_CERT_DN="cn=${HOSTNAME},ou=${CELL_NAME},ou=${NODE_NAME},o=${ORG_NAME},c=${ORG_COUNTRY}"
PERSONAL_CERT_EXPIRY=${PERSONAL_CERT_EXPIRY:=1}
SIGN_CERT_DN="cn=${HOSTNAME},ou=Root Certificate,ou=${CELL_NAME},ou=${NODE_NAME},o=${ORG_NAME},c=${ORG_COUNTRY}"
SIGN_CERT_EXPIRY=${SIGN_CERT_EXPIRY:=15}
KEYSTORE_PASSWORD=${KEYSTORE_PASSWORD:=12345678}
PORT_OFFSET=${PORT_OFFSET:=0}
PORTS_FILE=/tmp/${PROFILE_NAME}.portdef.props
WAS_NIC=${WAS_NIC:=enp0s3}
SCRIPTNAME=`basename $0`
#LOG=/var/tmp/${SCRIPTNAME}.log
LOG=/dev/null
export PATH=$PATH:/sbin:/usr/sbin
# END DECLARE CONSTANTS & ENVIRONMENT VARIABLES
#
# BEGIN DECLARE PROFILE PORT DEFINITIONS
WC_adminhost=${WC_adminhost:=9060}
WC_adminhost_secure=${WC_adminhost_secure:=9043}
BOOTSTRAP_ADDRESS=${BOOTSTRAP_ADDRESS:=9809}
SOAP_CONNECTOR_ADDRESS=${SOAP_CONNECTOR_ADDRESS:=8879}
IPC_CONNECTOR_ADDRESS=${IPC_CONNECTOR_ADDRESS:=9632}
SAS_SSL_SERVERAUTH_LISTENER_ADDRESS=${SAS_SSL_SERVERAUTH_LISTENER_ADDRESS:=9401}
CSIV2_SSL_SERVERAUTH_LISTENER_ADDRESS=${CSIV2_SSL_SERVERAUTH_LISTENER_ADDRESS:=9403}
CSIV2_SSL_MUTUALAUTH_LISTENER_ADDRESS=${CSIV2_SSL_MUTUALAUTH_LISTENER_ADDRESS:=9402}
ORB_LISTENER_ADDRESS=${ORB_LISTENER_ADDRESS:=9100}
CELL_DISCOVERY_ADDRESS=${CELL_DISCOVERY_ADDRESS:=7277}
DCS_UNICAST_ADDRESS=${DCS_UNICAST_ADDRESS:=9352}
DataPowerMgr_inbound_secure=${DataPowerMgr_inbound_secure:=5555}
XDAGENT_PORT=${XDAGENT_PORT:=7060}
OVERLAY_UDP_LISTENER_ADDRESS=${OVERLAY_UDP_LISTENER_ADDRESS:=11005}
OVERLAY_TCP_LISTENER_ADDRESS=${OVERLAY_TCP_LISTENER_ADDRESS:=11006}
STATUS_LISTENER_ADDRESS=${STATUS_LISTENER_ADDRESS:=9420}
# END DECLARE PROFILE PORT DEFINITIONS
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
    abort "WAS installation not found, aborting script.\n\n"
  else
    printf "=> WAS installation found.\n\n" | tee -a ${LOG}
  fi
}


# Function to assign ports based on an offset from the defaults.
assign_appsvr_ports() {
  
  WC_adminhost=$(( ${WC_adminhost} + ${PORT_OFFSET} ))
  WC_adminhost_secure=$(( ${WC_adminhost_secure} + ${PORT_OFFSET} ))
  BOOTSTRAP_ADDRESS=$(( ${BOOTSTRAP_ADDRESS} + ${PORT_OFFSET} ))
  SOAP_CONNECTOR_ADDRESS=$(( ${SOAP_CONNECTOR_ADDRESS} + ${PORT_OFFSET} ))
  IPC_CONNECTOR_ADDRESS=$(( ${IPC_CONNECTOR_ADDRESS} + ${PORT_OFFSET} ))
  SAS_SSL_SERVERAUTH_LISTENER_ADDRESS=$(( ${SAS_SSL_SERVERAUTH_LISTENER_ADDRESS} + ${PORT_OFFSET} ))
  CSIV2_SSL_SERVERAUTH_LISTENER_ADDRESS=$(( ${CSIV2_SSL_SERVERAUTH_LISTENER_ADDRESS} + ${PORT_OFFSET} ))
  CSIV2_SSL_MUTUALAUTH_LISTENER_ADDRESS=$(( ${CSIV2_SSL_MUTUALAUTH_LISTENER_ADDRESS} + ${PORT_OFFSET} ))
  ORB_LISTENER_ADDRESS=$(( ${ORB_LISTENER_ADDRESS} + ${PORT_OFFSET} ))
  CELL_DISCOVERY_ADDRESS=$(( ${CELL_DISCOVERY_ADDRESS} + ${PORT_OFFSET} ))
  DCS_UNICAST_ADDRESS=$(( ${DCS_UNICAST_ADDRESS} + ${PORT_OFFSET} ))
  DataPowerMgr_inbound_secure=$(( ${DataPowerMgr_inbound_secure} + ${PORT_OFFSET} ))
  XDAGENT_PORT=$(( ${XDAGENT_PORT} + ${PORT_OFFSET} ))
  OVERLAY_UDP_LISTENER_ADDRESS=$(( ${OVERLAY_UDP_LISTENER_ADDRESS} + ${PORT_OFFSET} ))
  OVERLAY_TCP_LISTENER_ADDRESS=$(( ${OVERLAY_TCP_LISTENER_ADDRESS} + ${PORT_OFFSET} ))
  STATUS_LISTENER_ADDRESS=$(( ${STATUS_LISTENER_ADDRESS} + ${PORT_OFFSET} ))

}


# Create new ports file.
create_ports_file() {
${SUDO} touch "${PORTS_FILE}"
${SUDO} chmod 666 "${PORTS_FILE}"

#Populate new ports file in correct format:
cat > "${PORTS_FILE}" << EOF
WC_adminhost=${WC_adminhost}
WC_adminhost_secure=${WC_adminhost_secure}
BOOTSTRAP_ADDRESS=${BOOTSTRAP_ADDRESS}
SOAP_CONNECTOR_ADDRESS=${SOAP_CONNECTOR_ADDRESS}
IPC_CONNECTOR_ADDRESS=${IPC_CONNECTOR_ADDRESS}
SAS_SSL_SERVERAUTH_LISTENER_ADDRESS=${SAS_SSL_SERVERAUTH_LISTENER_ADDRESS}
CSIV2_SSL_SERVERAUTH_LISTENER_ADDRESS=${CSIV2_SSL_SERVERAUTH_LISTENER_ADDRESS}
CSIV2_SSL_MUTUALAUTH_LISTENER_ADDRESS=${CSIV2_SSL_MUTUALAUTH_LISTENER_ADDRESS}
ORB_LISTENER_ADDRESS=${ORB_LISTENER_ADDRESS}
CELL_DISCOVERY_ADDRESS=${CELL_DISCOVERY_ADDRESS}
DCS_UNICAST_ADDRESS=${DCS_UNICAST_ADDRESS}
DataPowerMgr_inbound_secure=${DataPowerMgr_inbound_secure}
XDAGENT_PORT=${XDAGENT_PORT}
OVERLAY_UDP_LISTENER_ADDRESS=${OVERLAY_UDP_LISTENER_ADDRESS}
OVERLAY_TCP_LISTENER_ADDRESS=${OVERLAY_TCP_LISTENER_ADDRESS}
STATUS_LISTENER_ADDRESS=${STATUS_LISTENER_ADDRESS}


EOF
# Change ownership of ports file:
${SUDO} chown ${WAS_USER}:${WAS_GROUP} "${PORTS_FILE}"
printf "=> New ports file prepared.\n\n" | tee -a ${LOG}
}


# Create Deployment Manager profile.
create_profile_dmgr() {
  printf "Please wait while profile ${PROFILE_NAME} is created...\n\n" | tee -a ${LOG}
  ${SUDO} su - ${WAS_USER} -c "${WAS_ROOT}/bin/manageprofiles.sh -create -portsFile ${PORTS_FILE} \
    -validatePorts \
    -templatePath ${PROFILE_TEMPLATE} \
    -serverType ${PROFILE_TYPE} \
    -profileName ${PROFILE_NAME} \
    -profilePath ${PROFILE_PATH} \
    -nodeName ${NODE_NAME} \
    -hostName ${HOSTNAME} \
    -cellName ${CELL_NAME} \
    -enableAdminSecurity true \
    -adminUserName ${ADMIN_USER} \
    -adminPassword ${ADMIN_PASSWORD} \
    -personalCertDN "${PERSONAL_CERT_DN}" \
    -personalCertValidityPeriod ${PERSONAL_CERT_EXPIRY} \
    -signingCertDN "${SIGN_CERT_DN}" \
    -signingCertValidityPeriod ${SIGN_CERT_EXPIRY} \
    -keyStorePassword ${KEYSTORE_PASSWORD}"
  if [ "$?" -eq 0 ] ; then
    printf "\n=> ${PROFILE_NAME} profile creation has been successful.\n\n" | tee -a ${LOG}
  else
    abort  "A problem may have occurred with ${PROFILE_NAME} profile creation, aborting.\n\n" | tee -a ${LOG} 
  fi
}

# Run IVT.
run_ivt_dmgr() {
  printf "Running IVT for ${PROFILE_NAME} profile:" | tee -a ${LOG}
  ${SUDO} su - ${WAS_USER} -c "${PROFILE_PATH}/bin/ivt.sh ${SERVER_NAME} ${PROFILE_NAME}"
  if [ "$?" -eq 0 ] ; then
    printf " IVT completed successfully.\n\n" | tee -a ${LOG}
    return 0
  else
    printf "ERROR a problem occurred during IVT.\n\n" | tee -a ${LOG}
    return 1
  fi
}


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
  if [ -f "${PORTS_FILE}" ] ; then
    ${SUDO} rm -f "${PORTS_FILE}"
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


# Create profile:
assign_appsvr_ports
create_ports_file
create_profile_dmgr
run_ivt_dmgr


################### Configure firewall service for new profile ##################

# Create new firewalld service:
firewalld_service_create WAS-${PROFILE_NAME}

# Add required ports to firewalld service:
firewalld_service_port WAS-${PROFILE_NAME} ${WC_adminhost} tcp
firewalld_service_port WAS-${PROFILE_NAME} ${WC_adminhost_secure} tcp
firewalld_service_port WAS-${PROFILE_NAME} ${BOOTSTRAP_ADDRESS} tcp
firewalld_service_port WAS-${PROFILE_NAME} ${SOAP_CONNECTOR_ADDRESS} tcp
firewalld_service_port WAS-${PROFILE_NAME} ${IPC_CONNECTOR_ADDRESS} tcp
firewalld_service_port WAS-${PROFILE_NAME} ${SAS_SSL_SERVERAUTH_LISTENER_ADDRESS} tcp
firewalld_service_port WAS-${PROFILE_NAME} ${CSIV2_SSL_SERVERAUTH_LISTENER_ADDRESS} tcp
firewalld_service_port WAS-${PROFILE_NAME} ${CSIV2_SSL_MUTUALAUTH_LISTENER_ADDRESS} tcp
firewalld_service_port WAS-${PROFILE_NAME} ${ORB_LISTENER_ADDRESS} tcp
firewalld_service_port WAS-${PROFILE_NAME} ${CELL_DISCOVERY_ADDRESS} tcp
firewalld_service_port WAS-${PROFILE_NAME} ${DCS_UNICAST_ADDRESS} tcp
firewalld_service_port WAS-${PROFILE_NAME} ${DataPowerMgr_inbound_secure} tcp
firewalld_service_port WAS-${PROFILE_NAME} ${XDAGENT_PORT} tcp
firewalld_service_port WAS-${PROFILE_NAME} ${OVERLAY_UDP_LISTENER_ADDRESS} udp
firewalld_service_port WAS-${PROFILE_NAME} ${OVERLAY_TCP_LISTENER_ADDRESS} tcp
firewalld_service_port WAS-${PROFILE_NAME} ${STATUS_LISTENER_ADDRESS} tcp

# Add service to the public zone:
printf "\n=> Adding service to public zone: " | tee -a ${LOG}
${SUDO} firewall-cmd --permanent --zone=public --add-service=WAS-${PROFILE_NAME}

# Reload firewall:
printf "\n=> Reloading firewalld: " | tee -a ${LOG}
${SUDO} firewall-cmd --reload

################################################################################

# Cleanup operation:
cleanup

################################################################################

echo "============================" | tee -a ${LOG}
echo ENDING SCRIPT ON: | tee -a ${LOG}
date | tee -a ${LOG}

exit 0

