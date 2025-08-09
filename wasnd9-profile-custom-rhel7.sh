#!/bin/bash
#
################################################################################
#
# NAME:         wasnd9-profile-custom-rhel7.sh
# VERSION:      1.00
# DESCRIPTION:  Script to create an custom profile for a WAS 9 installation
#               on a RHEL7-based platforms, including federating it an existing
#               cell specified by a Dmgr. The constants and port definitions 
#               defined at the beginning of this script allow for a high degree
#               of customisation of the profile configuration.
#
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
PROFILE_TEMPLATE=${WAS_ROOT}/profileTemplates/managed
PROFILE_NAME=${PROFILE_NAME:=AppSrv01}
PROFILE_PATH=${WAS_ROOT}/profiles/${PROFILE_NAME}
HOSTNAME=`hostname`
NODE_NAME=${HOSTNAME}Node01
CELL_NAME=${NODE_NAME}Cell
DMGR_HOSTNAME=${DMGR_HOSTNAME:=centos70}
DMGR_IPADDRESS=${DMGR_IPADDRESS:=192.168.99.19}
DMGR_PORT=${DMGR_PORT:=8879}
DMGR_ADMIN_USER=${DMGR_ADMIN_USER:=wasadmin}
DMGR_ADMIN_PASSWORD=${DMGR_ADMIN_PASSWORD:=12345678}
ORG_NAME=${ORG_NAME:=testcompany}
ORG_COUNTRY=${ORG_COUNTRY:=GB}
PERSONAL_CERT_DN="cn=${HOSTNAME},ou=${CELL_NAME},ou=${NODE_NAME},o=${ORG_NAME},c=${ORG_COUNTRY}"
PERSONAL_CERT_EXPIRY=${PERSONAL_CERT_EXPIRY:=1}
SIGN_CERT_DN="cn=${HOSTNAME},ou=Root Certificate,ou=${CELL_NAME},ou=${NODE_NAME},o=${ORG_NAME},c=${ORG_COUNTRY}"
SIGN_CERT_EXPIRY=${SIGN_CERT_EXPIRY:=15}
KEYSTORE_PASSWORD=${KEYSTORE_PASSWORD:=12345678}
PORT_OFFSET=${PORT_OFFSET:=0}
NODE_PORTS_FILE=/tmp/${PROFILE_NAME}.portdef.props
WAS_NIC=${WAS_NIC:=enp0s3}
SCRIPTNAME=`basename $0`
#LOG=/var/tmp/${SCRIPTNAME}.log
LOG=/dev/null
export PATH=$PATH:/sbin:/usr/sbin
# END DECLARE CONSTANTS & ENVIRONMENT VARIABLES
#
# BEGIN DECLARE PROFILE PORT DEFINITIONS
BOOTSTRAP_ADDRESS=${BOOTSTRAP_ADDRESS:=2810}
SOAP_CONNECTOR_ADDRESS=${SOAP_CONNECTOR_ADDRESS:=8878}
IPC_CONNECTOR_ADDRESS=${IPC_CONNECTOR_ADDRESS:=9626}
SAS_SSL_SERVERAUTH_LISTENER_ADDRESS=${SAS_SSL_SERVERAUTH_LISTENER_ADDRESS:=9901}
CSIV2_SSL_SERVERAUTH_LISTENER_ADDRESS=${CSIV2_SSL_SERVERAUTH_LISTENER_ADDRESS:=9201}
CSIV2_SSL_MUTUALAUTH_LISTENER_ADDRESS=${CSIV2_SSL_MUTUALAUTH_LISTENER_ADDRESS:=9202}
ORB_LISTENER_ADDRESS=${ORB_LISTENER_ADDRESS:=9101}
NODE_DISCOVERY_ADDRESS=${NODE_DISCOVERY_ADDRESS:=7272}
NODE_IPV6_MULTICAST_DISCOVERY_ADDRESS=${NODE_IPV6_MULTICAST_DISCOVERY_ADDRESS:=5001}
NODE_MULTICAST_DISCOVERY_ADDRESS=${NODE_MULTICAST_DISCOVERY_ADDRESS:=5000}
DCS_UNICAST_ADDRESS=${DCS_UNICAST_ADDRESS:=9354}
XDAGENT_PORT=${XDAGENT_PORT:=7061}
OVERLAY_UDP_LISTENER_ADDRESS=${OVERLAY_UDP_LISTENER_ADDRESS:=11001}
OVERLAY_TCP_LISTENER_ADDRESS=${OVERLAY_TCP_LISTENER_ADDRESS:=11002}
# END DECLARE PROFILE PORT DEFINITIONS
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
    abort "WAS installation not found, aborting script.\n\n"
  else
    printf "=> WAS installation found.\n\n" | tee -a ${LOG}
  fi
}


# Ensure valid entry exists for Deployment Manager in /etc/hosts
hosts_dmgr_check() {
  egrep "^${DMGR_IPADDRESS}.*[[:blank:]]*${DMGR_HOSTNAME}[[:blank:]].*|^${DMGR_IPADDRESS}.*[[:blank:]]*${DMGR_HOSTNAME}$" /etc/hosts > /dev/null 2>&1
  if [ "$?" -eq 0 ] ; then
    printf "CHECK: Valid entry exists in local /etc/hosts file for DMGR.\n\n" | tee -a ${LOG}
  else
    if grep ^${DMGR_IPADDRESS} /etc/hosts > /dev/null 2>&1 ; then
      # Append required hostname if IP address found:
      ${SUDO} sed -i "/^${DMGR_IPADDRESS}/ s/$/ ${DMGR_HOSTNAME}/" /etc/hosts
    else
      # Append required entry to end of file:
      echo "${DMGR_IPADDRESS} ${DMGR_HOSTNAME}" | ${SUDO} tee -a /etc/hosts
    fi
  fi
}


# Function to assign ports based on an offset from the defaults.
assign_appsvr_ports() {
  
  BOOTSTRAP_ADDRESS=$(( ${BOOTSTRAP_ADDRESS} + ${PORT_OFFSET} ))
  SOAP_CONNECTOR_ADDRESS=$(( ${SOAP_CONNECTOR_ADDRESS} + ${PORT_OFFSET} ))
  IPC_CONNECTOR_ADDRESS=$(( ${IPC_CONNECTOR_ADDRESS} + ${PORT_OFFSET} ))
  SAS_SSL_SERVERAUTH_LISTENER_ADDRESS=$(( ${SAS_SSL_SERVERAUTH_LISTENER_ADDRESS} + ${PORT_OFFSET} ))
  CSIV2_SSL_SERVERAUTH_LISTENER_ADDRESS=$(( ${CSIV2_SSL_SERVERAUTH_LISTENER_ADDRESS} + ${PORT_OFFSET} ))
  CSIV2_SSL_MUTUALAUTH_LISTENER_ADDRESS=$(( ${CSIV2_SSL_MUTUALAUTH_LISTENER_ADDRESS} + ${PORT_OFFSET} ))
  ORB_LISTENER_ADDRESS=$(( ${ORB_LISTENER_ADDRESS} + ${PORT_OFFSET} ))
  NODE_DISCOVERY_ADDRESS=$(( ${NODE_DISCOVERY_ADDRESS} + ${PORT_OFFSET} ))
  NODE_IPV6_MULTICAST_DISCOVERY_ADDRESS=$(( ${NODE_IPV6_MULTICAST_DISCOVERY_ADDRESS} + ${PORT_OFFSET} ))
  NODE_MULTICAST_DISCOVERY_ADDRESS=$(( ${NODE_MULTICAST_DISCOVERY_ADDRESS} + ${PORT_OFFSET} ))
  DCS_UNICAST_ADDRESS=$(( ${DCS_UNICAST_ADDRESS} + ${PORT_OFFSET} ))
  XDAGENT_PORT=$(( ${XDAGENT_PORT} + ${PORT_OFFSET} ))
  OVERLAY_UDP_LISTENER_ADDRESS=$(( ${OVERLAY_UDP_LISTENER_ADDRESS} + ${PORT_OFFSET} ))
  OVERLAY_TCP_LISTENER_ADDRESS=$(( ${OVERLAY_TCP_LISTENER_ADDRESS} + ${PORT_OFFSET} ))
  
}


# Create a ports file specified by first argument.
create_ports_file() {
  if [ "$1" == "" ] ; then
    abort "Fully qualified name of ports file not specified, aborting.\n\n"
  else
    ${SUDO} touch "$1"
    ${SUDO} chmod 666 "$1"
    ${SUDO} chown ${WAS_USER}:${WAS_GROUP} "$1"
  fi
}


# Populate ports file for node agent - in correct format.
populate_node_ports_file() {

cat > "${NODE_PORTS_FILE}" << EOF
BOOTSTRAP_ADDRESS=${BOOTSTRAP_ADDRESS}
SOAP_CONNECTOR_ADDRESS=${SOAP_CONNECTOR_ADDRESS}
IPC_CONNECTOR_ADDRESS=${IPC_CONNECTOR_ADDRESS}
SAS_SSL_SERVERAUTH_LISTENER_ADDRESS=${SAS_SSL_SERVERAUTH_LISTENER_ADDRESS}
CSIV2_SSL_SERVERAUTH_LISTENER_ADDRESS=${CSIV2_SSL_SERVERAUTH_LISTENER_ADDRESS}
CSIV2_SSL_MUTUALAUTH_LISTENER_ADDRESS=${CSIV2_SSL_MUTUALAUTH_LISTENER_ADDRESS}
ORB_LISTENER_ADDRESS=${ORB_LISTENER_ADDRESS}
NODE_DISCOVERY_ADDRESS=${NODE_DISCOVERY_ADDRESS}
NODE_IPV6_MULTICAST_DISCOVERY_ADDRESS=${NODE_IPV6_MULTICAST_DISCOVERY_ADDRESS}
NODE_MULTICAST_DISCOVERY_ADDRESS=${NODE_MULTICAST_DISCOVERY_ADDRESS}
DCS_UNICAST_ADDRESS=${DCS_UNICAST_ADDRESS}
XDAGENT_PORT=${XDAGENT_PORT}
OVERLAY_UDP_LISTENER_ADDRESS=${OVERLAY_UDP_LISTENER_ADDRESS}
OVERLAY_TCP_LISTENER_ADDRESS=${OVERLAY_TCP_LISTENER_ADDRESS}
EOF

}


# Create App Server profile - without ports validation.
create_profile_custom() {
  printf "\nPlease wait while profile ${PROFILE_NAME} is created...\n\n" | tee -a ${LOG}
  ${SUDO} su - ${WAS_USER} -c "${WAS_ROOT}/bin/manageprofiles.sh -create -portsFile ${NODE_PORTS_FILE} \
    -validatePorts \
    -templatePath ${PROFILE_TEMPLATE} \
    -profileName ${PROFILE_NAME} \
    -profilePath ${PROFILE_PATH} \
    -nodeName ${NODE_NAME} \
    -hostName ${HOSTNAME} \
    -dmgrHost ${DMGR_HOSTNAME} \
    -dmgrPort ${DMGR_PORT} \
    -dmgrAdminUserName ${DMGR_ADMIN_USER} \
    -dmgrAdminPassword ${DMGR_ADMIN_PASSWORD} \
    -personalCertDN "${PERSONAL_CERT_DN}" \
    -personalCertValidityPeriod ${PERSONAL_CERT_EXPIRY} \
    -signingCertDN "${SIGN_CERT_DN}" \
    -signingCertValidityPeriod ${SIGN_CERT_EXPIRY} \
    -keyStorePassword ${KEYSTORE_PASSWORD}"
  if [ "$?" -eq 0 ] ; then
    printf "\n=> ${PROFILE_NAME} profile creation appears to have been successful.\n\n" | tee -a ${LOG}
  else
    abort "A problem may have occurred with ${PROFILE_NAME} profile creation, aborting.\n\n"
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
hosts_dmgr_check

# Define ports used by node agent for custom profile:
assign_appsvr_ports
create_ports_file ${NODE_PORTS_FILE}
populate_node_ports_file

################### Configure firewall service for new profile ##################
# Create new firewalld service:
firewalld_service_create WAS-${PROFILE_NAME}

# Add required ports to firewalld service:
firewalld_service_port WAS-${PROFILE_NAME} ${BOOTSTRAP_ADDRESS} tcp
firewalld_service_port WAS-${PROFILE_NAME} ${SOAP_CONNECTOR_ADDRESS} tcp
firewalld_service_port WAS-${PROFILE_NAME} ${IPC_CONNECTOR_ADDRESS} tcp
firewalld_service_port WAS-${PROFILE_NAME} ${SAS_SSL_SERVERAUTH_LISTENER_ADDRESS} tcp
firewalld_service_port WAS-${PROFILE_NAME} ${CSIV2_SSL_SERVERAUTH_LISTENER_ADDRESS} tcp
firewalld_service_port WAS-${PROFILE_NAME} ${CSIV2_SSL_MUTUALAUTH_LISTENER_ADDRESS} tcp
firewalld_service_port WAS-${PROFILE_NAME} ${ORB_LISTENER_ADDRESS} tcp
firewalld_service_port WAS-${PROFILE_NAME} ${NODE_DISCOVERY_ADDRESS} tcp
firewalld_service_port WAS-${PROFILE_NAME} ${NODE_IPV6_MULTICAST_DISCOVERY_ADDRESS} tcp
firewalld_service_port WAS-${PROFILE_NAME} ${NODE_MULTICAST_DISCOVERY_ADDRESS} tcp
firewalld_service_port WAS-${PROFILE_NAME} ${DCS_UNICAST_ADDRESS} tcp
firewalld_service_port WAS-${PROFILE_NAME} ${XDAGENT_PORT} tcp
firewalld_service_port WAS-${PROFILE_NAME} ${OVERLAY_UDP_LISTENER_ADDRESS} udp
firewalld_service_port WAS-${PROFILE_NAME} ${OVERLAY_TCP_LISTENER_ADDRESS} tcp

# Add service to the public zone:
printf "\n=> Adding service to public zone: " | tee -a ${LOG}
${SUDO} firewall-cmd --permanent --zone=public --add-service=WAS-${PROFILE_NAME}

# Reload firewall:
printf "\n=> Reloading firewalld: " | tee -a ${LOG}
${SUDO} firewall-cmd --reload

################################################################################
# Create custom profile:
create_profile_custom

################################################################################
# Remove temporary files used for profile creation:
cleanup

################################################################################

echo "============================" | tee -a ${LOG}
echo ENDING SCRIPT ON: | tee -a ${LOG}
date | tee -a ${LOG}

exit 0

