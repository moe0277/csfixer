# csfixer
CrowdStrike Bug Fixer for OCI Windows Platform Images 

PreReqs:

1. Must run on Oracle Autonomous Linux 8 deployed in the same AD as the affected windows instance. 
2. OAL 8 instance must be pre-configured w/ OCI CLI pointing to a user/tenancy which has control over and contains the affected windows instance. 

Instructions: 
1. Clone the code from github
2. Modify the csfixer.ini file and enter a valid ocid 
3. run ./csfixer.sh
