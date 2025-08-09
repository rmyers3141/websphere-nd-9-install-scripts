#!/bin/bash

# Run wsadmin Jython script:

/apps/IBM/WebSphere/AppServer/profiles/Dmgr01/bin/wsadmin.sh -lang jython -profileName Dmgr01 -username wasadmin -password 12345678 -f /scripts/was9/serverConfig_J27.py --server server1 --node centos70Node01 --retainlogs 14 --disableMQ --enableVGC


