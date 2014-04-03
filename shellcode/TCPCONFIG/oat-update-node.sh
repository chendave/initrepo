#!/bin/bash
# This script will register this node with an Open Attestation Service

# OAT Server FQDN
oat_svc_host=openattestation.domain.tld

# The IP we'll be contacting the OAT server *from* (could be a private IP)
ipaddr=10.20.0.11

if [ -z $oat_svc_host -o -z $ipaddr ]; then
    while [ "$1" != "${1##[-+]}" ]; do
      case $1 in
        '')    echo $"$0: Usage: $0 --oatserver=<fqdn oat server> --myip=<ip of nic contacting oatserver>}"
               exit 1;;
        --oatserver)
               oat_svc_host=$2
               shift 2
               ;;
        --oatserver=?*)
               oat_svc_host=${1#--oatserver=}
               shift
               ;;
        --myip)
               ipaddr=$2
               shift 2
               ;;
        --myip=?*)
               ipaddr=${1#--ipaddr=}
               shift
               ;;
        *)     echo $"$0: Usage: $0 --oatserver=<fqdn oat server> --myip=<ip of nic contacting oatserver>}"
               exit 1;;
      esac
    done
fi

# Our hostname (just to be sure).
hostname=`hostname -f`

# Get some details of the system (hardware, OS, etc.) to enter into the OAT db
oem_manu=`dmidecode -s system-manufacturer`
oem_desc=`dmidecode -s system-product-name`
os=`cat /etc/redhat-release | awk -F"release" '{print $1}'`
os_ver=`cat /etc/redhat-release | awk -F"release" '{print $2}'`
os_desc=$os
vmm=`virsh version | grep -i hyper | awk '{print $3}'`
vmm_ver=`virsh version | grep -i hyper | awk '{print $4}'`-$hostname
vmm_desc=$vmm
bios=`dmidecode -s bios-vendor`
bios_ver=`dmidecode -s bios-version`
bios_desc=`dmidecode -s baseboard-product-name`
pcr_00=`cat \`find /sys -name pcrs\` | grep PCR-00 | cut -c 8-80 | perl -pe 's/ //g'`
pcr_18=`cat \`find /sys -name pcrs\` | grep PCR-18 | cut -c 8-80 | perl -pe 's/ //g'`

echo \'$oat_svc_host\' \'$hostname\' \'$ipaddr\' \'$oem_manu\' \'$oem_desc\' \'$os\' \'$os_ver\' \'$os_desc\' \'$vmm\' \'$vmm_ver\' \'$vmm_desc\' \'$pcr_18\' \'$bios\' \'$bios_ver\' \'$bios_desc\' \'$pcr_00\'

# Enter VMM measured launch environment (mle) into the oat_db
oat_mle -e -h $oat_svc_host "{\"Name\":\"$vmm\",\"Version\":\"$vmm_ver\",\"OsName\":\"$os\",\"OsVersion\":\"$os_ver\",\"Attestation_Type\":\"PCR\",\"MLE_Type\":\"VMM\",\"Description\":\"$vmm_desc\",\"MLE_Manifests\":[{\"Name\":\"18\",\"Value\":\"$pcr_18\"}]}"

# Enter BIOS managed launch environment (mle) into the oat_db
oat_mle -e -h $oat_svc_host "{\"Name\":\"$bios\",\"Version\":\"$bios_ver\",\"OemName\":\"$oem_manu\",\"Attestation_Type\": \"PCR\",\"MLE_Type\":\"BIOS\",\"Description\":\"$bios_desc\",\"MLE_Manifests\":[{\"Name\":\"0\",\"Value\":\"$pcr_00\"}]}"

# attest the host
oat_pollhosts -h $oat_svc_host "{\"hosts\":[\"$hostname\"]}" | grep trusted &> /dev/null

if [ $? -eq 0 ]; then \
       echo "Node Attestation Successful!"
       exit 0
else
       echo "Node Attestation Failed!"
       exit 1
fi

