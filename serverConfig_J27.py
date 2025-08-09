#------------------------------------------------------------------------------
#    NAME: serverConfig_J27.py
# PURPOSE: Applies preferred settings to a WAS app server. The settings  
#          may incorporate "best practices" and/or corporate standards.
# VERSION: 1.0
#   NOTES: This script can apply the following settings to an
#          app server ( --server) residing on a node (--node), by using the
#          following options:
#
#          --retainlogs number
#              Changes the log rotation to daily (at midnight), with a 
#              retention period specified by 'number'. Applied to the
#              app server's SystemOut.log and SystemErr.log logs.
#
#          --enableVGC 
#              Enables verbose garbage collection on the app server.
#
#          --disableMQ
#              Disables MQ functionality on the app server.
#
#          All, or a subset, of the above options may be selected to 
#          selectively apply changes to a particular app server.  Only 
#          the --server and --node options are mandatory; if only these
#          options are chosen, then no real changes are made to the app
#          server, except for a restart.
# 
#          After changes are made, the configuration is saved, nodes are
#          synchronised and the application server restarted.
#
#          CHANGES FOR JYTHON 2.7:
#          -----------------------
#          os._exit() now raises an exception and will expect exception
#          handling.  Either modify script for exception handle os._exit(),
#          or use os._exit() instead. This script has been modified to
#          use os._exit() instead.
#
#          WAS 9:
#          ------
#          Verbose GC appears to be the default in WAS v9.
#
#------------------------------------------------------------------------------

import sys
import os
import getopt
import time
import re

# Global constants used in this script:
cellName = AdminControl.getCell()


# Function specifies correct script usage:
def usage():
    print
    print """This script must be used with the command-line syntax: 
  
    serverConfig_J27.py --server server --node node [--retainlogs number] [--enableVGC] [--disableMQ]

    """
#endDef
 

# Function gets required command-line arguments & processes accordingly:
def get_args():
    # Make args parameters global for use outside of this function:
    global s1, n1, rlogs, r1, vgc, nomq
    # Some parameters require initial defaults:
    rlogs = 'no'
    vgc = 'no'
    nomq = 'no'
    try:
        shortForm = ""
        longForm = ["server=", "node=", "retainlogs=", "enableVGC", "disableMQ"]
        argCount = len( sys.argv[0:])
        if (argCount < 4) :
            print "ERROR - Minimum no. of required command-line options have not been specified."
            usage()
            os._exit(2)
        #endIf
        opts, args = getopt.getopt(sys.argv[0:], shortForm, longForm)
    except getopt.GetoptError,  err:
        # Print usage before exiting:
        print str( err )
        print "Exception triggered!"
        usage()
        os._exit(2)
    #endTry
    # Process options:
    for flag, val in opts:
        if flag == '--server':
            s1 = val
            # TO-DO: Check this against a list of valid servers.
        elif flag == '--node':
            n1 = val
            # TO-DO: Check this against a list of valid nodes.
        elif flag == '--retainlogs':
            rlogs = 'yes'
            r1 = val
        elif flag == '--enableVGC':
            vgc = 'yes'
        elif flag == '--disableMQ':
            nomq = 'yes'
        else:
            usage()
            os._exit(2)
        #endIf
    #endFor
#endDef


# Function to change log settings for an app server's JVM log (log) to daily rotation at midnight.
# The function specifies the number of logs to retain on disk (backups).
def log_settings( log, backups ):
    try:
        logPolicy = AdminConfig.modify(log, [['rolloverType', 'TIME'], ['baseHour', 1], ['rolloverPeriod', 24], ['maxNumberOfBackupFiles', backups ]])
    except :
        # Report exception type and exception message if exception raised:
        print
        print "\nUNEXPECTED ERROR: ", sys.exc_info()[0], sys.exc_info()[1]
        os._exit(1)
    else:
        print "DONE."
    #endTry
#endDef


# Function to enable Verbose Garbage Collection for app server (svr) on node (nde). 
# Only enables VGC if not already set.
def enable_vgc( svr, nde ):
    getstring = '[-serverName ' + svr + ' -nodeName ' + nde + ' -propertyName verboseModeGarbageCollection]'
    setstring = '[-serverName ' + svr + ' -nodeName ' + nde + ' -verboseModeGarbageCollection true]'
    vgcvalue = AdminTask.showJVMProperties( getstring )
    if vgcvalue != 'true':
        print "VERBOSE GC NOT ENABLED ON " + svr + ", ENABLING...",
        try:
            setvgc = AdminTask.setJVMProperties( setstring )
        except:
            # Report exception type and exception message if exception raised:
            print
            print "\nUNEXPECTED ERROR: ", sys.exc_info()[0], sys.exc_info()[1]
            os._exit(1)
        else:
            print "DONE."
        #endTry
    else:
        print "VERBOSE GC ALREADY ENABLED ON " + svr + ", NO CHANGES MADE."
    #endIf
#endDef


# Function to disable MQ functionality for the app server (svr) on node (nde).
def disable_mq( svr, nde ) :
    # First determine server config ID:
    serverpath = '/Node:' + nde + '/Server:' + svr + '/'
    serverID = AdminConfig.getid( serverpath )
    # Now get a list of J2C Resource Adapters defined at the server scope:
    j2cRAs = AdminConfig.list( 'J2CResourceAdapter', serverID ).splitlines()
    # Construct regex to find the WebSphere MQ Resource Adapter:
    regex1 =  re.compile( '"WebSphere\sMQ\sResource\sAdapter*' )
    # Use the regex to filter for required element in the list:
    findj2c = filter( regex1.search, j2cRAs )
    # Only apply setting if a single match is found:
    if len( findj2c ) == 1 :
        wmqra = findj2c[0]
        print "DISABLING MQ FOR SERVER " + svr + " ON NODE " + nde + "...",
        applynomq = AdminTask.manageWMQ( wmqra, '[-disableWMQ true ]')
        if not applynomq :
            print "DONE."
        else :
            print "FAILED." 
        #endIf
    else :
        print "CANNOT FIND WebSphere MQ Resource Adapter WITHIN CONFIG SCOPE."
        os._exit( 1 )
    #endIf
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



# Main function:
def main():

    # First get command-line parameters:
    get_args()

    # Apply log rotation settings, if specified on command-line:
    if rlogs == "yes":
        # Define containment path of app server before getting its id:
        spath = '/Server:' + s1
        sid = AdminConfig.getid( spath )
        # Change log settings for SystemOut.log:
        print "CHANGING LOG ROTATION & RETENTION POLICY FOR", s1, "SystemOut.log FILE...",
        log1 = AdminConfig.showAttribute(sid, 'outputStreamRedirect')
        log_settings( log1, r1 )
        # Change log settings for SystemErr.log:
        print "CHANGING LOG ROTATION & RETENTION POLICY FOR", s1, "SystemErr.log FILE...",
        log2 = AdminConfig.showAttribute(sid, 'errorStreamRedirect')
        log_settings( log2, r1 )
    #endIf

    # Verbose GC settings: 
    if vgc == "yes":
        enable_vgc( s1, n1 )
    #endIf

    # MQ settings:
    if nomq == "yes":
        disable_mq( s1, n1 )
    #endIf

    # Save configuration:
    saveConfig()

    # Sync any active nodes:
    syncActiveNodes()

    # Restart app server for changes to take effect:
    restartAppSvr( s1, n1 )

    # Check app server has restarted:
    checkAppSvr( s1, n1 ) 
 
    # Exit from Jython with a specific exit code:
    os._exit(0)



# Ensure script is executed rather than imported:
if ( __name__ == '__main__' ):
    main()
else:
    print 'Error: this script must be executed, not imported.'
    usage()
    os._exit(1)
#endIf

