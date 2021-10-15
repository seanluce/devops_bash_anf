#!/bin/bash

# Create resource group
az group create --location $REGION --name $RG --tags $TAGS

# Create ANF account
az netappfiles account create --account-name $ACCOUNT --location $REGION --resource-group $RG


# Start DC 
echo "starting DC. Standby"
az vm start --ids /subscriptions/c560a042-4311-40cf-beb5-edc67991179e/resourceGroups/core.rg/providers/Microsoft.Compute/virtualMachines/DC-SouthCentral --verbose
echo DC started
echo " "

#Deploy Capacity Pool
echo "deploying capacity pool. Standby"
az netappfiles pool create -l $REGION -g $RG --account-name $ACCOUNT --name $POOL --size 4 --service-level $SVCLVL --tags $TAGS --verbose
echo "Capacity Pool $POOL deployed"

#get Pool resource ID
poolid=$(az netappfiles pool list -g $RG --account-name $ACCOUNT --query "[].id" --output tsv | grep $POOL)

# Deploy NFS volume
echo "deploying nfs volume. Standby"
az netappfiles volume create -g $RG --account-name $ACCOUNT --pool-name $POOL --name $NFSVOL --location $REGION --usage-threshold 100 --file-path $NFSVOL --vnet $VNET --subnet $ANFSUBNET --protocol-types NFSv3 --tags $TAGS --verbose
echo " "
echo "nfs volume $NFSVOL deployed."
echo " "

#Deploy SMB Volume
echo "deploying SMB volume. Standby"
az netappfiles volume create -g $RG --account-name $ACCOUNT --pool-name $POOL --name $SMBVOL --location $REGION --usage-threshold 100 --file-path $SMBVOL --vnet $VNET --subnet $ANFSUBNET --protocol-types CIFS --tags $TAGS --verbose
echo " "
echo "smb volume $SMBVOL deployed."

# deploy dual protocol nfsv3/smb volume
echo "deploying DP volume. Standby"
az netappfiles volume create -g $RG --account-name $ACCOUNT --pool-name $POOL --name $DPVOL --location $REGION --usage-threshold 100 --file-path $DPVOL --vnet $VNET --subnet $ANFSUBNET --protocol-types CIFS NFSv3 --security-style NTFS
echo " "
echo "DP volume $DPVOL deployed"

# Get volume resource IDs
volids=$(az netappfiles volume list -g $RG --account-name $ACCOUNT --pool-name $POOL --query '[].id' -o tsv)

echo "##################################################"
echo "# Resource IDs in case you need to configure CRR #"
echo "##################################################"
echo " "
echo $VOLIDS
echo " "
echo " "

# Create Windows VM
# manual:
# az vm create --name elfwindows --resource-group win.rg --image MicrosoftWindowsServer:WindowsServer:2019-Datacenter:latest --size Standard_D4s_v3 --location southcentralus --admin-username elfcounsel --admin-password Th0rS0n0f0den --vnet-name /subscriptions/c560a042-4311-40cf-beb5-edc67991179e/resourceGroups/core.rg/providers/Microsoft.Network/virtualNetworks/SouthCentral.vnet --subnet /subscriptions/c560a042-4311-40cf-beb5-edc67991179e/resourceGroups/core.rg/providers/Microsoft.Network/virtualNetworks/SouthCentral.vnet/subnets/VM.sn
echo "deploying Windows VM"
az vm create --name $WINNAME --resource-group $RG --image $WINIMAGE --size $VMSIZE --location $REGION --admin-username $USERNAME --admin-password $PASSWORD --subnet $VMSUBNET

echo "updating Windows VM DNS"
az network nic update --ids $(az network nic list -g $RG --query '[].id' -o tsv) --dns-servers 10.199.0.16
az vm restart --ids $(az vm list -g $RG --query '[].id' -o tsv)

# Create Linux VM
echo "deploying Ubuntu VM"
az vm create --name $LXNAME --resource-group $RG --image $LXIMAGE --size $VMSIZE --location $REGION --admin-username $USERNAME --admin-password $PASSWORD --subnet $VMSUBNET