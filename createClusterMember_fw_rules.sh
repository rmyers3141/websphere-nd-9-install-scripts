#!/bin/bash
#
################################################################################
#
# NAME:         AppServerPortsProps_wrapper_rhel7.sh
# VERSION:      1.00
# DESCRIPTION:  This script extracts the configuration of a WAS app server to a
#               properties file and reads it to determine the ports used by the 
#               app server.  It then uses these values to open the firewall 
#               ports on the host machine, using the firewalld program found on
#               RHEL7-based Linux platforms.  The ports are associated with a
#               particular firewalld service created specifically for the app 
#               server in question.
#
#               This script relies on the related Jython script called 
#               "AppServerProps_J27.py", whose full path must be specified
#               with the JYTHON_SCRIPT variable.
#
#               This script must be run on the machine hosting the WAS app 
#               server (WAS_SERVER), even though it connects to the 
#               Deployment Manager server to get the configuration info.
#
################################################################################
#
#
# BEGIN DECLARE CONSTANTS & ENVIRONMENT VARIABLES
WAS_USER=${WAS_USER:=wbsadm}
WAS_ROOT=${WAS_ROOT:=/apps/IBM/WebSphere/AppServer}
DMGR_HOSTNAME=${DMGR_HOSTNAME:=centos70}
DMGR_IPADDRESS=${DMGR_IPADDRESS:=192.168.99.19}
DMGR_PORT=${DMGR_PORT:=8879}
DMGR_ADMIN_USER=${DMGR_ADMIN_USER:=wasadmin}
DMGR_ADMIN_PASSWORD=${DMGR_ADMIN_PASSWORD:=12345678}
JYTHON_SCRIPT=${JYTHON_SCRIPT:=/scripts/was9/AppServerProps_J27.py}
WAS_SERVER=${WAS_SERVER:=server2}
FW_SERVICE=WAS-${WAS_SERVER}
PROPS_FILE=/tmp/${WAS_SERVER}.props
SCRIPTNAME=`basename $0`
#LOG=/var/tmp/${SCRIPTNAME}.log
LOG=/dev/null
export PATH=$PATH:/sbin:/usr/sbin
# END DECLARE CONSTANTS & ENVIRONMENT VARIABLES


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


# Function searches properties file $PROPS_FILE for port specifier ($1):
findPortValue() {
  portValue=
  portValue=`sed -n "s/$1=\(.*\):.*/\1/p" ${PROPS_FILE}`
  # echo $portValue
  if [ -z ${portValue} ]; then
    printf "$1 not found, ignoring.\n"
    return 1
  else
    return 0
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
  if [ -f "${PROPS_FILE}" ] ; then
    ${SUDO} rm -f "${PROPS_FILE}"
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
# Ensure supporting Jython script is available:
if [ ! -f "${JYTHON_SCRIPT}" ] ; then
  abort "Required script file ${JYTHON_SCRIPT} not found, aborting."
fi


# Extract WAS_SERVER properties to file:
${SUDO} su - ${WAS_USER} \
  -c "${WAS_ROOT}/bin/wsadmin.sh \
  -lang jython \
  -connType SOAP \
  -host ${DMGR_HOSTNAME} \
  -port ${DMGR_PORT} \
  -username ${DMGR_ADMIN_USER} \
  -password ${DMGR_ADMIN_PASSWORD} \
  -f ${JYTHON_SCRIPT} --server ${WAS_SERVER} --propsFile ${PROPS_FILE}"
if [ ! -f "${PROPS_FILE}" ] ; then
  abort "Props file not found, aborting!"
fi


#################### Begin Firewall Configuration #############################

# Create new firewalld service:
firewalld_service_create ${FW_SERVICE}


# Add WAS app server ports to firewalld service if defined in configuration.
# Hash-out any ports below that you want to remain blocked.

# SOAP_CONNECTOR_ADDRESS:
if findPortValue SOAP_CONNECTOR_ADDRESS ; then
  firewalld_service_port ${FW_SERVICE} ${portValue} tcp
fi

# SIP_DEFAULTHOST_SECURE:
if findPortValue SIP_DEFAULTHOST_SECURE ; then
  firewalld_service_port ${FW_SERVICE} ${portValue} tcp
fi

# SIP_DEFAULTHOST:
if findPortValue SIP_DEFAULTHOST ; then
  firewalld_service_port ${FW_SERVICE} ${portValue} tcp
fi

# SIB_ENDPOINT_ADDRESS:
if findPortValue SIB_ENDPOINT_ADDRESS ; then
  firewalld_service_port ${FW_SERVICE} ${portValue} tcp 
fi

# WC_defaulthost_secure:
if findPortValue WC_defaulthost_secure ; then
  firewalld_service_port ${FW_SERVICE} ${portValue} tcp
fi

# DCS_UNICAST_ADDRESS:
if findPortValue DCS_UNICAST_ADDRESS ; then
  firewalld_service_port ${FW_SERVICE} ${portValue} tcp
fi

# SIB_MQ_ENDPOINT_SECURE_ADDRESS:
if findPortValue SIB_MQ_ENDPOINT_SECURE_ADDRESS ; then
  firewalld_service_port ${FW_SERVICE} ${portValue} tcp
fi

# WC_adminhost_secure:
if findPortValue WC_adminhost_secure ; then
  firewalld_service_port ${FW_SERVICE} ${portValue} tcp
fi

# CSIV2_SSL_MUTUALAUTH_LISTENER_ADDRESS:
if findPortValue CSIV2_SSL_MUTUALAUTH_LISTENER_ADDRESS ; then
  firewalld_service_port ${FW_SERVICE} ${portValue} tcp
fi

# ORB_LISTENER_ADDRESS:
if findPortValue ORB_LISTENER_ADDRESS ; then
  firewalld_service_port ${FW_SERVICE} ${portValue} tcp
fi

# BOOTSTRAP_ADDRESS:
if findPortValue BOOTSTRAP_ADDRESS ; then
  firewalld_service_port ${FW_SERVICE} ${portValue} tcp
fi

# CSIV2_SSL_SERVERAUTH_LISTENER_ADDRESS:
if findPortValue CSIV2_SSL_SERVERAUTH_LISTENER_ADDRESS ; then
  firewalld_service_port ${FW_SERVICE} ${portValue} tcp
fi

# IPC_CONNECTOR_ADDRESS:
if findPortValue IPC_CONNECTOR_ADDRESS ; then
  firewalld_service_port ${FW_SERVICE} ${portValue} tcp
fi

# SIB_ENDPOINT_SECURE_ADDRESS:
if findPortValue SIB_ENDPOINT_SECURE_ADDRESS ; then
  firewalld_service_port ${FW_SERVICE} ${portValue} tcp
fi

# WC_defaulthost:
if findPortValue WC_defaulthost ; then
  firewalld_service_port ${FW_SERVICE} ${portValue} tcp
fi

# SIB_MQ_ENDPOINT_ADDRESS:
if findPortValue SIB_MQ_ENDPOINT_ADDRESS ; then
  firewalld_service_port ${FW_SERVICE} ${portValue} tcp
fi

# OVERLAY_UDP_LISTENER_ADDRESS:
if findPortValue OVERLAY_UDP_LISTENER_ADDRESS ; then
  firewalld_service_port ${FW_SERVICE} ${portValue} udp
fi

# SAS_SSL_SERVERAUTH_LISTENER_ADDRESS:
if findPortValue SAS_SSL_SERVERAUTH_LISTENER_ADDRESS ; then
  firewalld_service_port ${FW_SERVICE} ${portValue} tcp
fi

# OVERLAY_TCP_LISTENER_ADDRESS:
if findPortValue OVERLAY_TCP_LISTENER_ADDRESS ; then
  firewalld_service_port ${FW_SERVICE} ${portValue} tcp
fi

# WC_adminhost:
if findPortValue WC_adminhost ; then
  firewalld_service_port ${FW_SERVICE} ${portValue} tcp
fi


##############################################################################

# Add service to the public zone:
printf "\n=> Adding service to public zone: " | tee -a ${LOG}
${SUDO} firewall-cmd --permanent --zone=public --add-service=WAS-${WAS_SERVER}

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

