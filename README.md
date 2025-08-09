# websphere-nd-9-install-scripts
A suite of Unix shell and Jython scripts for the automated install and basic configuration of a multi-node [IBM WebSphere Application Server Network Deployment v9](https://www.ibm.com/docs/en/was-nd/9.0.5?topic=network-deployment-all-operating-systems-version-90) cell.

This will be of interest to anyone with a good knowledge of ***IBM WebSphere Application Server Network Deployment*** and familiarity with scripting.

## Overview
The installation and configuration of a *IBM WebSphere Application Server Network Deployment v9* (hereafter just referred to as *WAS v9*) can be time-consuming, highly complex, and very labour-intenstive if done manually.

The scripts in this repo allows for the automation of much of this work to save time while providing a basic clustered multi-node configuration which is typical of many real-world Production deployments.

The scripts have to be run in a particular sequence (see below), with some of the `bash` scripts acting as "wrapper" scripts for calling accompanying Jython scripts.   Some of the configuration scripts can be omitted, or modified, to suit particular requirements.

For further detailed information about each of the scripts, please consult the `DESCRIPTION` text block at the beginning of each script.

***NOTE:*** *Some of the `bash` scripts currently only run on Red Hat Enterprise Linux (RHEL) v7-based platforms, but with a little work, these can be adapted for newer related platforms.*

The scripts have been tested and verified as working to construct a two-node WAS cluster, but in theory they could be used to build much larger clusters.

## Prerequisites
Before executing the scripts you will need:

- [x] At least two machines running a RHELv7-compatible operating system.  Ideally, each machine should have a hostname alias resolvable by all the other machines and remote clients.

- [x] A user account on the machines having root-level privileges (such as with `sudo`).

- [x] Ensure the target machines have access to a `yum` repository that gives it access to download and install the following `.rpm` packages and package groups (or at least have these pre-installed):

`glibc.x86_64, libgcc.x86_64, kernel-headers.x86_64, libstdc++.x86_64, compat-libstdc++-33.x86_64, @X Window System, gtk2.x86_64, gtk2, libXtst, xorg-x11-fonts-Type1, psmisc, firefox.x86_64`

(*Check IBM Prerequisites for WAS v9 and underlying O.S. if you are working on a newer platform as the required packages might differ.*)

- [x] A licensed copy of the [IBM Installation Manager](https://www.ibm.com/docs/en/installation-manager/1.9.2?topic=manager-installation-overview) installation software uploaded to each machine to the folder `/kits/IBM/iim`.  The `iim-install-linux-x64.sh` script assumes this version 1.8 (`agent.installer.linux.gtk.x86_64_1.8.8000.20171130_1105.zip`), but it is recommended to download the latest version from IBM and change the `IIM_MEDIA` variable in the `iim-install-linux-x64.sh` script to the version being used).

- [x] A licensed copy of the *IBM WebSphere Application Server Network Deployment v9* and *IBM Java SDK v8* installation software.  These are available from **IBM Passport Advantage** if you are paid-up customer, or you can download time-limited evaluation copies.   The `wasnd9-install-rhel7.sh` script assumes the use of `com.ibm.websphere.ND.v90_9.0.4.20170523_1327` and `com.ibm.java.jdk.v8_8.0.4070.20170629_1222` versions respectively, so update the script appropriately if using different versions.

- [x] The `wasnd9-install-rhel7.sh` script uses a answer file `was9nd-sdk8_install_response_v1.01.xml` that assumes the above installation software is held on a shared web-based *"Composite"* IBM Installation Manager repository" `https://repo.iim.test/repo/composite/` that is securely accessed using a `master_password.txt` and `credential.store` file.  If you are not using such a repository, the `wasnd9-install-rhel7.sh` script and `was9nd-sdk8_install_response_v1.01.xml` response file will need to be modified first.  (*However, creating such a web-base repository is considered best-practice and recommended if time allows, but is beyond the scope of this GitHub repository.  Check IBM's documentation on how to set up such a repository.*)


## EXECUTION OF THE SCRIPTS
Before executing the scripts, consult the `DESCRIPTION` text at the beginning of each script and, if required, modify any default variable settings to suit your requirements (such as changing default passwords, port settings, etc).  The default values are given in curly braces `{}`, for example:
```sh
WAS_ROOT=${WAS_ROOT:=/apps/IBM/WebSphere/AppServer}
```
These default values can be overriden by specifying a new value preceding script execution, for example `WAS_ROOT=/opt/WAS/AppServer`.

Please also check the `was9nd-sdk8_install_response_v1.01.xml` response file as well as that also uses some custom variable definitions.

Some scripts need to run on all machines, while others on only on specific machines (depending on their role).   To save time, just upload <ins>all</ins> the scripts from this repo to <ins>all</ins> the machines into a holding directory `/scripts/was9/`, (some of the scripts assume this is their default location), and ensure the `bash` scripts are given executable permission:

```sh
$ mkdir -p /scripts/was9
$ chmod +x /scripts/was9/*.sh
```

For all scripts, your will need to logon as a user on each machine with root-level privileges, (either the `root` user or a user with root-level privileges granted via `sudo`), in order to execute them.

Follow the script execution as detailed in the subsections below, but if a script fails do not precede any further!  (Most of the scripts complete with an exit code of `0` if run successfully). 


### I. Scripts to run on all machines
First, the following scripts must be run on **<ins>all</ins>** machines.   (This can be done simultaneously across all participating machines if desired).

Before beginning, ensure *IBM Installation Manager* installation media has been uploaded to each machine.  (The script `iim-install-linux-x64.sh` assumes it is to be found in the directory `/kits/IBM/iim`, so amend the script variable appropriately if the the path is different).

Change to the directory containing the scripts and run the scripts in the order below; wait for each script to complete successfully before executing the next one in the sequence:
```sh
$ cd /scripts/was9
$ ./wasnd9-prep-rhel7.sh
$ ./iim-install-linux-x64.sh
$ ./wasnd9-install-rhel7.sh
```
These scripts install prerequisite .rpms for the O.S., IBM Installation Manager (as a non-Admin user `wbsadm`), and the WAS binaries.  NOTE - The `wbsadm` user (and group of the same name) is set up to own and run the WAS installation.

### II. Scripts to run on the *Deployment Manager* machine
After all the above scripts have been run successfully, chose one machine to be the designated *Deployment Manager* machine and run the following scripts on that machine:
```sh
$ ./wasnd9-profile-dmgr-rhel7.sh
```
This will create the Deployment Manager profile on the machine.

The following two scripts can also be run on this machine, but are optional:  
```sh
$ ./wasOpsUser_wrapper_J27.sh
$ PROFILE_PATH=/apps/IBM/WebSphere/AppServer/profiles/Dmgr01 ./was-soapclient-update.sh
```
`wasOpsUser_wrapper_J27.sh` calls the Jython script `wasOpsUser_J27.py` and creates a WAS user with *Operator* level permissions.  While the `was-soapclient-update.sh` script then updates the `soap.client.props` under the Deployment Manager profile path (specified by the `PROFILE-PATH` variable) with the Ops user details.  The operator-level user allows for start, stop, restart operations to be executed without needing admin-level permissions.

The following script is also optional:
```sh
$ WAS_TYPE=DeploymentManager ./was-systemd-unit-create.sh
```
This creates a `systemd` unit file to manage the Deployment Manager as a system service that can started, stopped, restarted, and auto-started at boot time.  You must specify the variable `WAS_TYPE=DeploymentManager` immediately before running this script.

### III. Scripts to create Application Server Profiles
Once the above scripts (**I** and **II** above) have completed successfully, the following script needs to be run on any machines that will host *Application Server* profiles.  This might include the *Deployment Manager* machine, but best practice is to deploy to non-Deployment Manager machines.

```sh
$ ./PROFILE_NAME=AppSrv01 ./wasnd9-profile-custom-rhel7.sh
```
This script creates as **Custom** WAS profile (i.e. just a *Node Agent*) called `AppSrv01` on the machine - although you can choose a different name by changing the value given for `PROFILE_NAME`.  Run this script on all machines intended to host Application Server Profiles.

Like the Deployment Manager machine (**II** above), the following scripts are also optional.   They also set up the *Ops* user in the local `soap.client.props` file and create a system service for the profile's Node Agent process:

Before running the following script, change the `PROFILE_PATH` variable to a suitable value is required:
```sh
$ PROFILE_PATH=/apps/IBM/WebSphere/AppServer/profiles/AppSrv01 ./was-soapclient-update.sh
```

```sh
$ WAS_TYPE=NodeAgent PROFILE_PATH=/apps/IBM/WebSphere/AppServer/profiles/AppSrv01 ./was-systemd-unit-create.sh
```
Note that in the above, the `WAS_TYPE` and `PROFILE_PATH` variables must be set appropriately before script execution (consult the script's `DESCRIPTION` for further details).

### IV. Application Server and Cluster Creation
The scripts in this section must be run from the *Deployment Manager* machine.

Define variables appropriately, then run the following script to create a WAS application server instance on a specific node:
```sh
$ ./createAppServer_wrapper.sh
```
(You can repeat this on other Application Server Profile nodes if desired to create other application servers, but it is more typical to use this as the basis to create a cluster - see below).

Once the app server has been created you can (optionally) reset its ports - which is considered best practice for a Production system - by pre-setting certain script variables or editing the script variable definitions in-place:
```sh
$ ./AppServerPortsProps_wrapper_rhel7.sh
```
(Consult the `DESCRIPTION` at the beginning of this script which gives extensive information of what variables to set, and how to define things like the `PORT_OFFSET`).

The following script is also optional.  It sets some preferred application server settings such as log file rotation, enabling verbose garbage collection (now the default in WAS v9), and disables some MQ functions inherent in newly created application servers (IBM recommend disabling these if not required as best practice).

Edit the values, as appropriate, specified on the script's `wsadmin.sh` command-line options before executing it:
```sh
$ ./serverConfig_wrapper.sh
```

Now that an application server instance has been created with all the desired properties, we use it as a basis to create a cluster by running the following script.  Edit the values, as required, specified on the script's `wsadmin.sh` command-line options before executing:
```sh
$ ./createCluster_wrapper
```
(This script calls the Jython script `createCluster_J27.py`).

### V. Creating further Cluster Members
Section **IV**. above created a single server cluster with a desired configuration.  Now, if required, we can add further members to the cluster using the first cluster member acting as a template.

To do this, edit the values, as required, specified in the script's `wsadmin.sh` command-line options before executing it:
```sh
$ ./createClusterMember_wrapper.sh
```
This script can be executed remotely from the *Deployment Manager* machine, which is very useful as it can be adapted to read the local machine's hostname and infer the node name and other local values. 


### VI. Script Completion.
Once all the above script executions have completed you should have a WAS cell with a single cluster.

If required, you can repeat **IV** and **V** above to create any further clusters in the cell to a desired configuration.


## Background Notes
### Motivation
This project is a primarily proof-of-concept into the automated installation and configuration of a WAS clustered cell.

The manual installation of a complex clustered WAS cell can take days, or even longer.   The scripts in this repo have successfully completed a typical set up in just a matter of hours.

The scripts themselves are not intended for Production use, but rather as as a ***starting point*** to understand and encapsulate the steps necessary to build a Production-ready WAS cell in the shortest time possible.  The intention is to use this to inform deployments using modern automation platforms such as *Ansible* and *Terraform*.


### How the scripts work
Detailed information for how each script works is given in the `DESCRIPTION` text at the beginning of each script.   It is too complex to go into detail here, so here is a high-level overview of how they work:

- All the scripts that are executed are `bash` scripts; some of these may call one or more Jython scripts.

- Most the the scripts use a common set of variables, for example `WAS_ROOT` and have a default value set within the scripts e.g. `WAS_ROOT=${WAS_ROOT:=/apps/IBM/WebSphere/AppServer}`.  However these can be overriden by defining a new value on the command line before script execution.

- Most of the scripts are constructed from <ins>functions</ins> (both `bash` functions and Jython functions).   This should allow for easy updating.

- Some of the scripts configure `firewalld` port settings for WAS-specific ports. But if you have `firewalld` disabled, you could omit the functions that implement this.

- Some of the WAS configuration steps (such as port reassignments, app server configuration, cluster set-up) are based on real-world experience from building large Production systems.

- Some of the scripts have more functionality built into them than is apparent from their execution.  For example, the `iim-install-linux-x64.sh` script is also capable of installing *IBM Installation Manager* in *admin*-mode and *group*-mode, as well as the default *user*-mode.

- Because of similarities between WAS v9 and WAS v8.5.5, the scripts can easily be adapted to create a WAS v8.5.5 cell as well.


### TO-DO List
There are many improvements to the scripts that can be made, too numerous to list here, but here are some suggestions:

- The scripts could benefit by leveraging automation tools such as *Ansible Playbooks* as well as being adapted for newer Linux platforms.
  
- WAS best practice is to use custom SSL certificates (e.g. from a corporate or private PKI).  The scripts could be adapted to get these from a *Vault* along with other secrets like passwords, rather than have them hard-coded into the scripts.

- After creating the WAS profiles, use the `wsadmin` command `AdminTask.changeMultipleKeyStorePasswords()` to reset the default passwords in all the keystores as they currently use the default password.

- Theoretically, `was-systemd-unit-create.sh` script can also create a `systemd` service for the application servers, but IBM don't currently recommend this.  Instead they suggest the Node Agents be configured to auto-start the application server instances.

- Create separate filesystems for logs, transaction logs (if exist), core and heap dumps, and each profile.  Also, secure the file system permissions on these filesystems.
  
- Verify the installation by deploying a test application and then undeploying it.

- Further WAS hardening and configuration lock down (a vast topic!).



