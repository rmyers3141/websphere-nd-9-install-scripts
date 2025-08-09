#!/bin/bash
#
################################################################################
#
# NAME:         was-profile-soap-props.sh
# VERSION:      1.00
# DESCRIPTION:  Modifies the soap.client.props file for a WebSphere Application 
#               Server (WAS) profile so that a specific internal WAs user 
#               (WAS_OPS_USER) can be used for unprompted run-time operations.
#
#               The user is intended to support run-time operations such as
#               start, stop, and status operations.  This user account must 
#               be specified in this script with the WAS_OPS_USER variable 
#               and should already exist in the WAS configuration.  Preferably, 
#               it should have the minimum privileges for such run-time 
#               operations such as "Operator" role rights.
#
#               Set the constants below appropriate to the target environment.
#               The values given below are examples and can be overriden by
#               feeding alternative values to the script from the environment,
#               for example:
#
#               PROFILE_PATH=/opt/WAS/profiles/AppSrv01 ./was-init.sh 
#
#
#               
#
################################################################################
#
#
# BEGIN DECLARE CONSTANTS & ENVIRONMENT VARIABLES
WAS_USER=${WAS_USER:=wbsadm}
WAS_OPS_USER=${WAS_OPS_USER:=wasops1}
WAS_OPS_PWD=${WAS_OPS_PWD:=12345678}
PROFILE_PATH=${PROFILE_PATH:=/apps/IBM/WebSphere/AppServer/profiles/AppSrv01}
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


# Update soap.client.props file, if found ,with desired changes.
soap_file_update () {
  targetFile="${PROFILE_PATH}/properties/soap.client.props"
  backupFile="${PROFILE_PATH}/properties/soap.client.props_${SCRIPTNAME}.bak"
  # First check file exists and make a backup if found:
  if [ ! -f ${targetFile} ] ; then
    abort "${targetFile} NOT FOUND, ABORTING SCRIPT."
  else
    ${SUDO} su - ${WAS_USER} -c "cp -p ${targetFile} ${backupFile}"
  fi
  # Now make required changes to file, rollback if any changes fail:
  ${SUDO} su - ${WAS_USER} -c \
  "sed -i -e 's/^com.ibm.SOAP.securityEnabled=.*/com.ibm.SOAP.securityEnabled=true/' \
          -e 's/^com.ibm.SOAP.loginUserid=.*/com.ibm.SOAP.loginUserid=${WAS_OPS_USER}/' \
          -e 's/^com.ibm.SOAP.loginPassword=.*/com.ibm.SOAP.loginPassword=${WAS_OPS_PWD}/' \
             ${targetFile}"
  if [ "$?" -eq 0 ] ; then
    ${SUDO} su - ${WAS_USER} -c \
    "${PROFILE_PATH}/bin/PropFilePasswordEncoder.sh ${targetFile} com.ibm.SOAP.loginPassword" > /dev/null 2>&1
    if [ "$?" -eq 0 ] ; then
      printf "=> FILE ${targetFile} UPDATED SUCCESSFULLY!\n\n" | tee -a ${LOG}
    else
      ${SUDO} su - ${WAS_USER} -c "mv ${backupFile} ${targetFile}"
      abort "PROBLEM ENCODING FILE ${targetFile}. ROLLING BACK & ABORTING SCRIPT."
    fi
  else
    ${SUDO} su - ${WAS_USER} -c "mv ${backupFile} ${targetFile}"
    abort "PROBLEM UPDATING FILE ${targetFile}. ROLLING BACK & ABORTING SCRIPT."
  fi
}


# MAIN
sudo_check
soap_file_update

