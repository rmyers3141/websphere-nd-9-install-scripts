#!/bin/bash

# Run wsadmin Jython script:

/apps/IBM/WebSphere/AppServer/profiles/Dmgr01/bin/wsadmin.sh -lang jython -profileName Dmgr01 -username wasadmin -password 12345678 -f /scripts/was9/createAppServer_J27.py --nodeName centos70Node01 --serverName server1 --templateName default


