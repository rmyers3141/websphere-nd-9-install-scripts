#------------------------------------------------------------------------------
#    NAME: wasOpsUser_J27.py
# PURPOSE: Sets up an internal WAS user with 'operator' rights only 
#          exclusively for managing run-time operations. Using such an
#          account, with the bare-minimum of required privileges, is considered
#          more secure than using an account with higher-level privileges.
# VERSION: 1.0
#   NOTES: This script first creates a group and user in the default
#          o=defaultWIMFileBasedRealm internal file repository. The user is
#          added to the group, before the group itself is assigned the 
#          'operator' role.
#        
#          The naming conventions, etc, assigned to the group can be 
#          found under the section  "Global constants used in this script".
#          The user parameters, on the other hand, must be specified
#          on the script's command line.  These are: the username (--id), 
#          password (-password), common name (--commoname) and surname 
#          (--surname) of the user you wish to create. 
#
#          NOTE:
#          -----
#          By carefully editing this script, it could also be used to create
#          any other user/group combination with different administrative
#          role privileges.
#
#          CAVEAT:
#          -------
#          Currently, only basic exception handling is built into this script, 
#          e.g. it will simply exit if an exception is encountered. This might 
#          be because a user, group, etc, may already exist. However, this 
#          script is only really intended for use during the initial build 
#          phase of a WAS installation, so such groups/users are not 
#          anticipated to exist anyway.
#
# 
#          After changes are made, the configuration is saved and any active 
#          nodes are synchronised. 
#
#          After running this script Deployment Manager (in an ND environment) 
#          or the app server (in a stand-alone environment) should then be 
#          restarted.  This is not performed by this script.
#
#          CHANGES FOR JYTHON 2.7:
#          -----------------------
#          os._exit() now raises an exception and will expect exception 
#          handling.  Either modify script for exception handle os._exit(),
#          or use os._exit() instead. This script has been modified to 
#          use os._exit() instead.
#
#------------------------------------------------------------------------------


import getopt
import sys
import os


# Global constants used in this script:
groupcn = 'wasops'
groupdesc = 'WAS Operators Group'
adminrole = 'operator'



# Function specifies correct script usage:
def usage():
    print
    print """This script must be used with the command-line syntax: 
  
    wasOpsUser.py --id username --passphrase password --commoname first_name --surname surname

    """
#endDef


# Function gets required command-line arguments & processes accordingly:
def get_args() :
    # Make args parameters global for use outside of this function:
    global userid, passwd, cname, sname
    # Some parameters require initial defaults:
    try:
        shortForm = ""
        longForm = ["id=", "passphrase=", "commoname=", "surname="]
        argCount = len( sys.argv[0:])
        if ( argCount < 8 ) :
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
        if flag == '--id':
            userid = val
        elif flag == '--passphrase':
            passwd = val
        elif flag == '--commoname':
            cname  = val
        elif flag == '--surname':
            sname = val
        else:
            usage()
            os._exit(2)
        #endIf
    #endFor
#endDef


# Function to create group.
def createGroup( grpcn, grpdesc ):
    global grpfqdn
    try:
        grpfqdn = AdminTask.createGroup(['-cn', grpcn, '-description', grpdesc])
    except:
        # Report exception type and exception message if exception raised:
        print
        print "\nUNEXPECTED ERROR: ", sys.exc_info()[0], sys.exc_info()[1]
        os._exit(1)
    else:
        print "GROUP CREATED:", grpfqdn
    #endTry
#endDef


# Function to create user.
def createUser( username, password, commonname, surname ):
    global userfqdn
    try:
        userfqdn = AdminTask.createUser(['-uid', username, '-password', password, '-cn', commonname, '-sn', surname ])
    except:
        # Report exception type and exception message if exception raised:
        print
        print "\nUNEXPECTED ERROR: ", sys.exc_info()[0], sys.exc_info()[1]
        os._exit(1)
    else:
        print "USER CREATED:", userfqdn
    #endTry
#endDef


# Function to add user to group.
def addToGroup( user, group ):
    try:
        addResult = AdminTask.addMemberToGroup(['-memberUniqueName', user, '-groupUniqueName', group ])
    except:
        # Report exception type and exception message if exception raised:
        print
        print "\nUNEXPECTED ERROR: ", sys.exc_info()[0], sys.exc_info()[1]
        os._exit(1)
    else:
        print "USER ADDED TO GROUP", group, ":", addResult 
    #endTry
#endDef


# Function to assign role to group.
def groupRoleMap( group, realm = 'defaultWIMFileBasedRealm' ):
    # First construct string for configuration:
    roleConfig = '[-roleName ' + adminrole + ' -accessids [group:' + realm + '/' + group + ' ] -groupids [' + group[3:] + ' ]]'
    try:
        roleResult = AdminTask.mapGroupsToAdminRole( roleConfig )
    except:
        # Report exception type and exception message if exception raised:
        print
        print "\nUNEXPECTED ERROR: ", sys.exc_info()[0], sys.exc_info()[1]
        os._exit(1)
    else:
        if roleResult:
            print "GROUP", group, "ASSIGNED TO ROLE:", adminrole
        else:
            print "ROLE ASSIGNMENT FAILED, EXITING...."
            os._exit(1)
        #endIf
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
    # First get command-line arguments: 
    get_args()

    # Create Group:
    createGroup( groupcn, groupdesc ) 

    # Create User:
    createUser( userid, passwd, cname, sname )

    # Add User to Group:
    addToGroup( userfqdn, grpfqdn )

    # Assign Role to Group:
    groupRoleMap( grpfqdn )

    # Save configuration:
    saveConfig()  

    # Sync any active nodes:
    # No need, as no nodes exist at this stage!
    #syncActiveNodes()
 
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

