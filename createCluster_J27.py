#------------------------------------------------------------------------------
#    NAME: createCluster_J27.py
# PURPOSE: Creates a new WAS cluster based on an existing app server. 
# VERSION: 1.0
#   NOTES: This script uses the AdminTask.createCluster() method to create
#          an APPLICATION_SERVER type cluster using having certain default
#          values (see # Cluster Default Values below).  The cluster is 
#          created by converting an existing application server as the
#          first member of the cluster.
#
#          This script must be run by specifiying the following options:
#
#          --cluster cluster_name
#              Specify the name of the cluster to create.
#
#          --server server_name
#              Specify the name of the app server that becomes the first
#              member of the cluster.
#
#          --node node_name
#              Specify the node on which the app server exists.
# 
#          After changes are made, the configuration is saved and nodes are
#          synchronised.
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
import os
import getopt

# Global constants used in this script:
# Cluster default values.
preferlocal = 'true'
clustertype = 'APPLICATION_SERVER'


# Function specifies correct script usage:
def usage():
    print
    print """This script must be used with the command-line syntax: 
  
    createCluster_J27.py --cluster cluster_name --server server_name --node node_name

    """
#endDef
 

# Function gets required command-line arguments & processes accordingly:
def get_args():
    # Make args parameters global for use outside of this function:
    global c1, s1, n1
    # Some parameters require initial defaults:
    try:
        shortForm = ""
        longForm = ["cluster=", "server=", "node="]
        argCount = len( sys.argv[0:])
        if ( argCount < 6 ):
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
        if flag == '--cluster':
            c1 = val
        elif flag == '--server':
            s1 = val
        elif flag == '--node':
            n1 = val
        else:
            usage()
            os._exit(2)
        #endIf
    #endFor
#endTry


# Function to create cluster (clstr) based on a server (svr) residing on node (nde).
# Uses certain default values (see above) for creating the cluster.
def cluster_create( clstr, srvr, nde ):
    # First construct that specifies the desired cluster config & server to convert:
    config = '[-clusterConfig [-clusterName ' + clstr + ' -preferLocal ' + preferlocal + ' -clusterType ' + clustertype + ']' + \
    ' -convertServer ' + '[-serverNode ' + n1 + ' -serverName ' + s1 + ']]'
    try:
        print "CREATING NEW CLUSTER ", clstr, "..."
        newcluster = AdminTask.createCluster( config ) 
    except:
        # Report exception type and exception message if exception raised:
        print
        print "\nUNEXPECTED ERROR: ", sys.exc_info()[0], sys.exc_info()[1]
        os._exit(1)
    else:
        print "...CLUSTER CREATED WITH CONFIG ID: ", newcluster
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

    # Create cluster:
    cluster_create( c1, s1, n1 )

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

