# csfixer
CrowdStrike Bug Fixer for OCI Windows Platform Images 

PreReqs:

1. Must run on Oracle Autonomous Linux 8 deployed in the same AD as the affected windows instance. 
2. OAL 8 instance must be pre-configured w/ OCI CLI pointing to a user/tenancy which has control over and contains the affected windows instance. 
	2a. Info on OCI CLI configuration can be found here: https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm#configfile

Instructions: 
1. Clone the code from github
2. Modify the csfixer.ini file and enter a valid ocid (of the affected Windows compute instance - non-bitlocker)
3. run ./csfixer.sh
