#!/bin/bash
# vim: tabstop=4 shiftwidth=4 softtabstop=4 expandtab nowrap:
#
# 
# 

function intro() { 
	echo -e "CSFixer v0.1"
	echo -e
	echo -e "Accepts 2 parameters - uuid of windows compute and this linux compute via csfixer.ini" 
	echo -e
	echo -e "1. Stops the windows compute instance."
	echo -e "2. Triggers a backup of the windows compute instance's boot volume." 
	echo -e "3. Detaches the boot volume and attaches it to this linux node. (assumes non-bitlocker)" 
	echo -e "4. Mounts volume on this linux node and cleans the offending files."
	echo -e "5. Detaches the boot volume and re-attaches it to windows compute instance." 
	echo -e "6. Restarts windows compute instances."
	echo -e
	echo -e "csfixer new run:" > csfixer.log
	data &>csfixer.log
}

function prereqs() { 
	echo -en "Checking pre-reqs..."
	cat /etc/redhat-release | grep Ootpa &>csfixer.log
	if [ "$?" != "0" ]; then
		echo -e 
		echo "ERROR: Not running on OL 8, aborting" 
		exit 1
	fi

	yum-config-manager --enable ol8_baseos_latest ol8_appstream ol8_addons ol8_developer_EPEL &>>csfixer.log

	if [ "$?" != "0" ]; then
		echo -e "Error encountered..."
		exit 1
	fi

	if ! yum list installed ntfs-3g &>>csfixer.log; then 
		echo -e
		echo -en "NOTE: Installing ntfs-3g..." 
		yum install -y ntfs-3g &>>csfixer.log
		echo -e  "completed"
	fi

	if ! yum list installed ntfsprogs &>>csfixer.log; then 
		echo -e 
		echo -en "NOTE: Installing ntfsprogs..."
		yum install -y ntfsprogs &>>csfixer.log
		echo -e "completed" 
	fi

	echo "completed" 
}

function readini() {
	echo -en "Reading csfixer.ini..."
	source csfixer.ini
	echo -e "completed" 
	echo -e 
	echo Windows Instance ID: ${WININSTANCE}
	echo Fixer   Instance ID: ${FIXINSTANCE} 
	echo -e
	echo -e
}

function getbootvol() {
	echo -en "Getting Windows Instance boot volume id..." 
	instanceInfo=$(oci compute instance get --instance-id "$WININSTANCE" 2>>csfixer.log)
	if [ "$?" != "0" ]; then 
		echo "Error encountered:" $instanceInfo
		exit 1
	fi
	#echo $instanceInfo
	availabilityDomain=$(echo "$instanceInfo" | jq -r '.data["availability-domain"]')
	compartmentID=$(echo "$instanceInfo" | jq -r '.data["compartment-id"]')
	instanceID=$(echo "$instanceInfo" | jq -r '.data["id"]')

	#echo $availabilityDomain
	#echo $compartmentID
	#echo "InstanceID: " $instanceID

	BVData=$(oci compute boot-volume-attachment list --instance-id ${instanceID} --compartment-id ${compartmentID} --availability-domain ${availabilityDomain} 2>>csfixer.log)
	if [ "$?" != "0" ]; then 
		echo "Error encountered: " $BVData
		exit 1
	fi
	#echo $BVData

	bvID=$(echo "$BVData" | jq -r '.data[]["boot-volume-id"]')
	#echo $bvID
	echo "completed" 
}
function stopwindowsinstance() {
	echo -en "Stopping Windows Instance..." 

	instanceAction=$(oci compute instance action --action STOP --instance-id ${instanceID} --wait-for-state STOPPED 2>>csfixer.log)
	if [ "$?" != "0" ]; then 
		echo "Error encountered: " $instanceAction 
		exit 1
	fi
	echo -e "completed"
}
function takebackup() {
	echo -en "Create a backup of windows instance boot volume, may take a few mins..."
	bvbackup=$(oci bv boot-volume-backup create --boot-volume-id $bvID --wait-for-state AVAILABLE --display-name "backup-pre-cs-clean" 2>>csfixer.log)
	if [ "$?" != "0" ]; then
		echo "Error encountered: " $bvbackup
	fi
	echo -e "completed"
}
function detachbootvolfromwindows() {
	echo -en "Detach boot volume from windows instance..."
	echo -e "completed"
}
function attachvoltolinux() {
	echo -en "Attach volume to linux instance..."
	echo -e "completed"
}
function fixvolume() {
	echo -en "Fixing volume..."
	echo -e "completed" 
}
function detachbootvolfromlinux() {
	echo -en "Detaching volume from linux instance..."
	echo -e "completed"
}
function attachvoltowindows() {
	echo -en "Reattaching boot volume to windows instance..."
	echo -e "completed"
}
function startwindowsinstance() {
	echo -en "Starting windows instance..."
	echo -e "completed"
}


#intro
#prereqs
readini
getbootvol
#stopwindowsinstance
#takebackup
detachbootvolfromwindows
#attachvoltolinux
#fixvolume
#detachbootvolfromlinux
#attachvoltowindows
#startwindowsinstance
