#------------------------------------------------------------------------------
#        NAME: AppServerProps_J27.py
#     PURPOSE: Extract config of a WAS app server to a properties file. 
# PREQUISITES: This script must be run with the following mandatory options:
#
#              --server
#                  The name of the WAS app server whose properties you wish to
#                  extract.
#
#              --propsFile
#                  The full path to the properties file you wish to extract to.
#
#
#     VERSION: 1.0
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
import getopt



# Function specifies correct script usage:
def usage():
    print """Script must be used with command-line options as follows:
  
    AppServerProps_J27.py --server server_name --propsFile props_file 
  
    The full path to the properties files must be given."""
#endDef 


# Function gets required command-line arguments and specifies other required parameters.
def getArgs():
    # Make these args global for use outside of this function:
    global serverName, serverProps
    try:
        shortForm = ''
        longForm = ["server=", "propsFile="]
        argCount = len( sys.argv[0:])
        if (argCount < 4):
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
        elif flag == '--propsFile':
           serverProps  = val
        else:
            usage()
            os._exit(2)
        #endIf
    #endFor
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



# Main function:
def main() :
    # First get required parameters:
    getArgs()

    # Extract server configuration to props file:
    extractConfigProps( serverProps, serverName )

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

