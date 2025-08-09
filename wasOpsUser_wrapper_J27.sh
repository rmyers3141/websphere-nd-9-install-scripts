#!/bin/bash

# Run wsadmin Jython script:

/apps/IBM/WebSphere/AppServer/profiles/Dmgr01/bin/wsadmin.sh -lang jython -profileName Dmgr01 -username wasadmin -password 12345678 -f /scripts/was9/wasOpsUser_J27.py --id wasops1 --passphrase 12345678  --commoname was --surname ops1


# Restart of DMGR required:
/apps/IBM/WebSphere/AppServer/profiles/Dmgr01/bin/stopManager.sh -username wasadmin -password 12345678
sleep 5
/apps/IBM/WebSphere/AppServer/profiles/Dmgr01/bin/startManager.sh

