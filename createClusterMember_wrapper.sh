#!/bin/bash

# Run wsadmin Jython script as user that owns WAS:

su - wbsadm -c "/apps/IBM/WebSphere/AppServer/bin/wsadmin.sh -lang jython -connType SOAP -host centos70 -port 8879 -username wasadmin -password 12345678 -f /scripts/was9/createClusterMember_J27.py --cluster Cluster01 --server server2 --node centos702Node01"

