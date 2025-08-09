#------------------------------------------------------------------------------
#        NAME: AppServerPortsProps_J27.py
#     PURPOSE: Modifies the End Points (i.e. ports) of a WAS app server using 
#              properties files.   
# PREQUISITES: 1. Before running this script, you must first prepare a properties 
#              file containing the End Point (i.e. port) definitions
#              that you require to be applied to app server.  Entries in this 
#              file must have the format:
#
#              END_POINT_NAME=new_port_number
#
#              Each entry must be displayed on a separate line.  You do not 
#              necessarily need to specify all the End Point definitions, if 
#              you are only changing a subset of defintions, but it is 
#              probably best practice to do so anyway.
#             
#              Specify the full path to this properties file using the 
#              --newprops option when running this script.
#
#              2.  The app server must already exist. It doesn't matter if it
#              is already running, but it must be restarted for the changes to 
#              take effect. This script restarts it after changes have been
#              made.
#             
#              Specify the name of the application server using the --server 
#              option when running this script.
#
#              3. The node the app server is running on must also be specified
#              using the --node option.
#
#              THIS SCRIPT WILL FAIL TO RUN UNLESS THE ABOVE OPTIONS ARE GIVEN.
#
#     VERSION: 1.0
#       NOTES: This script uses AdminTask methods to export the entire
#              configuration of an app server (--server) to a properties file.
#              It then modifies properties in this file according 
#              according to new values (chosen by the user) in a different
#              properties file (--newprops).  Once modified and verified, it
#              is applied to the current app server configuration.  A restart
#              of the app server is required afterwards for changes to take 
#              effect. 
#
#              This script is specifically designed to modify the End Points
#              (i.e. port values) of an app server, but could be modified to
#              change other properties, if desired.
#
#
#              CHANGES FOR JYTHON 2.7:
#              -----------------------
#              os._exit() now raises an exception and will expect exception
#              handling.  Either modify script for exception handle os._exit(),
#              or use os._exit() instead. This script has been modified to
#              use os._exit() instead.
#
#------------------------------------------------------------------------------


import sys
import os
#import os.path
import getopt
import re
import time
import shutil


# Global constants used in this script:
cellName = AdminControl.getCell()


# Parameters used by functions such as createUnixTempDir().
# Set these according to the name of the script and the O.S. environment first.
scriptbasename = 'AppServerPortsProps'
temproot = '/tmp'


# Function specifies correct script usage:
def usage():
    print """Script must be used with command-line options as follows:
  
    AppServerPorts_J27.py --server server_name --node node_name --newprops new_props_file 
  
    The full path to the properties files must be given."""
#endDef 


# Function gets required command-line arguments and specifies other required parameters.
def getArgs():
    # Make these args global for use outside of this function:
    global serverName, nodeName, newPropsFile
    try:
        shortForm = ''
        longForm = ["server=", "node=", "newprops="]
        argCount = len( sys.argv[0:])
        if (argCount < 6):
            print "Insufficient parameters specified!"
            usage()
            os._exit(2)
        #endIf
        opts, args = getopt.getopt(sys.argv[0:], shortForm, longForm)
    except getopt.GetoptError,  err:
        # Print usage before exiting:
        print str(err)
        print "Exception triggered!"
        usage()
        os._exit(2)
    #endTry
    # Process options:
    for flag, val in opts:
        if flag == '--server':
            serverName = val
        elif flag == '--node':
            nodeName = val
        elif flag == '--newprops':
            newPropsFile = val
        else:
            usage()
            os._exit(2)
        #endIf
    #endFor
#endDef


# Function to create unique temporary working dir for the script on Unix systems:
def createUnixTempDir():
    global tempdir
    timestamp = str( int( time.time() ) )
    tempdir = temproot + '/' + scriptbasename + timestamp
    if not os.path.exists(tempdir):
        os.makedirs(tempdir)
    #endIf
#endDef


# Function to check file exists.
def pathCheck( p1 ) :
    if not os.path.isfile( p1 ) :
        print "FILE NOT FOUND: "+p1
        print "EXITING..."
        os._exit(1)
    #endif
#endDef


# Function to extract server configuration to properties file.
def extractConfigProps( f1, s1 ) :
    try:
        extractParams = '-propertiesFileName ' + f1 + ' -configData Server=' + s1
        extractResult = AdminTask.extractConfigProperties( extractParams )
    except :
        # Report exception type and exception message if exception raised:
        print
        print "UNEXPECTED ERROR: ", sys.exc_info()[0], sys.exc_info()[1]
        os._exit(1)
    else :
        print "CURRENT CONFIGURATION FOR " + s1 + " SUCCESSFULLY EXTRACTED TO: " + f1
    #endTry
#endDef


# Function modifies contents of a 'destination' file (f1) with text 
# found in a 'source' file (f2).  Regular expression searching is
# used to find the desired text in f2 and to apply it to relevant  
# 'matching' text in f1.
# THIS SCRIPT:  In the context of this script, f1 denotes the 
# server properties file ( oldPropsFile ), while f2 denotes the file
# containing new End Point definitions ( newPropsFile ) that need
# to be applied to f1.
# TO-DO: this function needs to be improved with some exception handling.
def editConfigProps( f1, f2 ):
    file2 = open( f2, 'r' )
    lines = file2.readlines()
    # Filter for only relevant lines:
    regex1 = re.compile( '\S=\d+' )
    targetlines = filter( regex1.search, lines )
    file2.close()
    file1 = open( f1, 'r' )
    contents1 = file1.read()
    file1.close()
    for line in targetlines :
        newlinestrip =  line[:-1]
        basestring = newlinestrip.split( '=' )[0]
        patstring = basestring + '=\d+'
        contents1 = re.sub( patstring, newlinestrip, contents1 )
    #endFor
    file1 = open( f1, 'w' )
    file1.write( contents1 )
    file1.close()
    print "FILE " + f1 + " UPDATED WITH CONFIG FROM " + f2
#endDef


# Function to validate the configuration in the modified properties file.
def validateConfig( f1 ):
    validateParams = '-propertiesFileName ' + f1 + ' -reportFileName ' + tempdir + '/report.txt'
    validateResult = AdminTask.validateConfigProperties( validateParams )
    if not validateResult:
        print "ERROR: FAILED TO VALIDATE NEW CONFIGURATION, EXITING..."
        os._exit(1)
    else :
        print "NEW CONFIGURATION VALIDATED."
    #endIf
#endDef


# Function to apply the validated configuration to the WAS configuration.
def applyConfig( f1 ):
    applyParams = '-propertiesFileName ' + f1 + ' -validate true'
    applyResult = AdminTask.applyConfigProperties( applyParams )
    if applyResult:
        print "ERROR: FAILED TO APPLY NEW CONFIGURATION, EXITING..."
        os._exit(1)
    else:
        print "NEW CONFIGURATION APPLIED SUCCESSFULLY."
    #endif
#endDef


# Save WAS Configuration:
def saveConfig():
    print "SAVING CONFIGURATION ...",
    saveResult = AdminConfig.save()
    if not saveResult:
        print "DONE."
    else:
        print "A PROBLEM OCCURRED SAVING, EXITING."
        os._exit(1)
    #endIf
#endDef


# Sync active nodes:
def syncActiveNodes():
    dmgrMB = AdminControl.queryNames("type=DeploymentManager,*")
    print "SYNCING ACTIVE NODES ...",
    syncResult = AdminControl.invoke(dmgrMB, 'syncActiveNodes', 'true')
    if syncResult:
        print "DONE."
    else:
        print "NO NODES SYNC'D."
    #endIf
#endDef


# Simple function to restart app server (svr) on node (nde) so changes can take effect.
# TO-DO: this function might be improved with some exception handling.
def restartAppSvr( svr, nde ):
    # Construct object reference for app server:
    svrobj = 'cell=' + cellName + ',node=' + nde + ',name=' + svr + ',type=Server,*'
    # Then determine if an MBean exists for this object:
    svrmb = AdminControl.completeObjectName( svrobj )
    # Start / restart logic based on whether MBean exists for server:
    if not svrmb:
        print "STARTING APP SERVER FOR CHANGES TO TAKE EFFECT..." 
        AdminControl.startServer( svr, nde )
    else:
        restartResult = AdminControl.invoke( svrmb, 'restart' )
        if not restartResult :
            print "RESTARTING APP SERVER FOR CHANGES TO TAKE EFFECT..."
        else:
            print "A PROBLEM OCCURRED DURING RESTART OF: " + svr
        #endIf
    #endIf
#endDef
  

# Function to check app server (svr) on node (nde) has restarted.
# Status is determined by getting status of the server MBean.
# By default, checks 10 times every 10 seconds, this can be changed if desired.
def checkAppSvr( svr, nde, snooze = 10, retries = 10 ):
    svrstate = ""
    svrobj = 'cell=' + cellName + ',node=' + nde + ',name=' + svr + ',type=Server,*'
    for n in range(0, retries):
        svrmb = AdminControl.completeObjectName(svrobj)
        try:
            svrstate = AdminControl.getAttribute(svrmb, 'state')
        except:
            pass
        #endTry
        if svrstate != "STARTED":
            time.sleep(snooze)  
            print '.',
        else:
            break
        #endIf
    #endFor
    print "APP SERVER " + svr + " STATUS: " + svrstate
#endDef


###############################################################################
 

# Main function:
def main() :
    # First get required parameters:
    getArgs()

    # Verify existence of new props file:
    pathCheck( newPropsFile ) 

    # Create a temporary working directory for this script.
    createUnixTempDir()

    # Extract server configuration to props file in temp dir:
    serverPropsFile = tempdir + '/server_config.props'
    extractConfigProps( serverPropsFile, serverName )

    # Modify current props file with values in new props file:
    editConfigProps( serverPropsFile, newPropsFile )

    # Validate modified props file:
    validateConfig( serverPropsFile )
  
    # Apply new config to WAS:
    applyConfig( serverPropsFile )

    # Save configuration:
    saveConfig()

    # Sync any active nodes:
    syncActiveNodes()

    # Restart app server for changes to take effect:
    restartAppSvr( serverName, nodeName ) 

    # Check for completed startup:
    checkAppSvr( serverName, nodeName )
  
    # Cleanup:
    shutil.rmtree( tempdir )

    # Exit from Jython with a specific exit code:
    os._exit(0)
#endDef


# Ensure script is executed rather than imported:
if ( __name__ == '__main__' ):
    main()
else:
    print 'Error: this script must be executed, not imported.'
    usage()
    os._exit(1)
#endIf

