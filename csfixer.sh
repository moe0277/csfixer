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
	date &>csfixer.log
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
	#echo Fixer   Instance ID: ${FIXINSTANCE} 
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
function getfixerinfo() { 
    
    fixerInfo=$(curl -s -H "Authorization: Bearer Oracle" -L http://169.254.169.254/opc/v2/instance/ 2>>csfixer.log)
    if [ "$?" != "0" ]; then
        echo "Error occured: " $fixerInfo
        exit 1
    fi
    fixerID=$(echo "$fixerInfo" | jq -r '.id')
    #echo "Fixer instance OCID: $fixerID"
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
        exit 1
	fi
	echo -e "completed"
}
function detachbootvolfromwindows() {
	echo -en "Detach boot volume from windows instance..."
    detachInfo=$(oci compute boot-volume-attachment detach --boot-volume-attachment-id $instanceID --force --wait-for-state DETACHED 2>>csfixer.log)
    if [ "$?" != "0" ]; then
        echo "Error encountered: " $detachInfo
        exit 1
    fi
	echo -e "completed"
}

function attachvoltofixer() {
	echo -en "Attach volume to fixer instance..."
    attachInfo=$(oci compute volume-attachment attach-paravirtualized-volume --instance-id $fixerID --volume-id $bvID --wait-for-state ATTACHED 2>>csfixer.log)    
    if [ "$?" != "0" ]; then
        echo "Error encountered: " $attachInfo
        exit 1
    fi
	echo -e "completed"
}
function fixvolume() {
	echo -en "Fixing volume..."
    mkdir i
    ntfs-3g.probe --readwrite /dev/sdb4 2>>csfixer.log
    if [ "$?" != "0" ]; then
        #windows volume is dirty - attempt fix
        ntfsfix /dev/sdb4 2>>csfixer.log
        if [ "$?" != "0" ]; then
            echo "Error encountered, trying to fix ntfs volume.. aborting"
            exit 1
        fi
    fi
    
    mount /dev/sdb4 i 
    rm -rf i/Windows/System32/drivers/CrowdStrike/c-00000291*.sys 2>>csfixer.log
    rm -rf i/Windows/System32/drivers/CrowdStrike/C-00000291*.sys 2>>csfixer.log
    umount i
	echo -e "completed" 
}
function detachbootvolfromfixer() {
	echo -en "Detaching volume from linux instance..."
    detachInfo=$(oci compute volume-attachment list --instance-id "$fixerID" 2>>csfixer.log)
    if [ "$?" != "0" ]; then
        echo "Error encountered: " $detachInfo
    fi

    #echo "Detach Info:" $detachInfo
    #echo "BVID: " $bvID

    attachID=$(echo "$detachInfo" | jq -r --arg bvID "$bvID" '.data[] | select(.["volume-id"] == $bvID and .["lifecycle-state"] == "ATTACHED") | .id')
   
    #echo "Attach ID" $attachID 
    detachInfo=$(oci compute volume-attachment detach --volume-attachment-id $attachID --force --wait-for-state DETACHED 2>>csfixer.log)
    if [ "$?" != "0" ]; then
        echo "Error encountered: " $detachInfo
        exit 1
    fi  
	echo -e "completed"
}
function attachvoltowindows() {
	echo -en "Reattaching boot volume to windows instance..."
    attachInfo=$(oci compute boot-volume-attachment attach --boot-volume-id $bvID --instance-id $instanceID --wait-for-state ATTACHED 2>>csfixer.log)
    if [ "$?" != "0" ]; then
        echo -e "Error encountered: " $attachInfo
        exit 1
    fi
	echo -e "completed"
}
function startwindowsinstance() {
	echo -en "Starting windows instance..."
    startInfo=$(oci compute instance action --action START --instance-id $instanceID --wait-for-state RUNNING 2>>csfixer.log)
    if [ "$?" != "0" ]; then
        echo "Error encountered: " $startInfo
        exit 1
    fi
	echo -e "completed"
}


intro
prereqs
readini
getbootvol
getfixerinfo
stopwindowsinstance
takebackup
detachbootvolfromwindows
attachvoltofixer
fixvolume
detachbootvolfromfixer
attachvoltowindows
startwindowsinstance
