#!/bin/bash

# Run wsadmin Jython script:

/apps/IBM/WebSphere/AppServer/profiles/Dmgr01/bin/wsadmin.sh -lang jython -profileName Dmgr01 -username wasadmin -password 12345678 -f /scripts/was9/createCluster.py --cluster Cluster01 --server server1 --node centosNode01


