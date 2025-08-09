#------------------------------------------------------------------------------
#    NAME: createAppServer.py
# PURPOSE: To create WebSphere Application Server instance on a specified node. 
# VERSION: 1.0
#   NOTES: Specify the name of the new app server to be created using the
#          --serverName option, the node on which each should be created using  
#          the --nodeName option, and the template to use for creating the app
#          server using the --templateName option.  The latter usually takes
#          the value "default".
#
#
#          CHANGES FOR JYTHON 2.7:
#          -----------------------
#          os._exit() now raises an exception and will expect exception
#          handling.  Either modify script for exception handle os._exit(),
#          or use os._exit() instead. This script has been modified to
#          use os._exit() instead.
#
#------------------------------------------------------------------------------

import sys
import getopt
import os


# Function specifies correct script usage:
def usage():
    print
    print """This script must be used with command-line syntax: 
  
    createAppServer.py --nodeName node --serverName server --templateName template

    """
#endDef


# Function gets required command-line arguments:
def get_args():
    # Make these args global for use outside of this function:
    global n1, s1, t1
    try:
        shortForm = ""
        longForm = ["nodeName=", "serverName=", "templateName="]
        argCount = len( sys.argv[0:])
        if ( argCount < 6 ) :
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
        if flag == '--nodeName':
            n1 = val
        elif flag == '--serverName':
            s1 = val
        elif flag == '--templateName' :
            t1 = val
        else :
            usage()
            os._exit(2)
        #endIf
    #endFor
#endTry


# Function to create app server on specified node:
def create_server( node, server, template = 'default' ):
    try:
        print
        print "ATTEMPTING TO CREATE SERVER", server, "ON NODE", node, "..."
        serverID = AdminTask.createApplicationServer( node, [ '-name', server, '-templateName', template ] )
    except:
        # Report exception type and exception message if exception raised:
        print
        print "UNEXPECTED ERROR: ", sys.exc_info()[0], sys.exc_info()[1]
        os._exit(1)
    else :
        print "SERVER", server, "CREATED ON NODE", node, "with ID:"
        print serverID
    #endTry
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


# Main function:
def main():
    # First get command-line parameters:
    get_args()

    # Then create new app server:
    create_server( n1, s1, t1 )

    # Save configuration:
    saveConfig()

    # Sync any active nodes:
    syncActiveNodes()

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

