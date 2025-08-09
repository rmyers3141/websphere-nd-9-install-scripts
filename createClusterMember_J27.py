#------------------------------------------------------------------------------
#    NAME: createClusterMember_J27.py
# PURPOSE: Creates a new WAS app server cluster member.
# VERSION: 1.0
#   NOTES: This script uses the AdminTask.createClusterMember() method to 
#          add a new application server member to an existing 
#          APPLICATION_SERVER cluster.
#
#          The script assumes the cluster already has at least one member 
#          and that the first member acts as a template for the creation of 
#          new members.
#
#          This script must be run by specifiying the following options:
#      
#          --cluster cluster_name
#              Specify the name of the existing cluster.
#
#          --server server_name
#              Specify the name of the app server that will be created and
#              become a member of the cluster.
#
#          --node node_name
#              Specify the node on which the new app server member is created.
#
# 
#          After changes are made, the configuration is saved and nodes are
#          synchronised.
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

import os
import sys
import getopt


# Function specifies correct script usage:
def usage():
      print
      print """This script must be used with the command-line syntax: 
  
      createClusterMember.py --cluster cluster_name --server server_name --node node_name

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
    for flag, val in opts :
        if flag == '--cluster':
            c1 = val
        elif flag == '--server':
            s1 = val
        elif flag == '--node':
            n1 = val
        else :
            usage()
            os._exit(2)
        #endIf
    #endFor
#endDef


# Function to create new app server (svr) residing on node (nde) as a member
# of an existing cluster (clstr).
def cluster_newmember( clstr, srvr, nde ):
    # First construct that string specifies the desired cluster member configuration:
    config = '[-clusterName ' + clstr + ' -memberConfig ' + ' [-memberNode ' + n1 + ' -memberName ' + s1 + ']]'
    try:
        print "CREATING NEW CLUSTER MEMBER", srvr , "ON CLUSTER", clstr, "..."
        newmember = AdminTask.createClusterMember( config ) 
    except:
        # Report exception type and exception message if exception raised:
        print
        print "\nUNEXPECTED ERROR: ", sys.exc_info()[0], sys.exc_info()[1]
        os._exit(1)
    else:
        print "...CLUSTER MEMBER CREATED WITH CONFIG ID: "
        print newmember
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

    # Create new cluster member:
    cluster_newmember( c1, s1, n1 )

    # Save configuration:
    saveConfig()

    # Sync any active nodes:
    syncActiveNodes()
 
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

