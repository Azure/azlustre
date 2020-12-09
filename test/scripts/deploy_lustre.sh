#!/bin/bash

name=$1
instanceCount=$2
rsaPublicKey=$3
imageResourceGroup=$4
imageName=$5
existingVnetResourceGroupName=$6
existingVnetName=$7
existingSubnetName=$8
lustreTier=$9
ossDiskSetup=${10}

if [ "$lustreTier" = "eph" ]; then
    mdsSku=Standard_L8s_v2
    ossSku=Standard_L48s_v2
    mdtStorageSku=Premium_LRS
    mdtCacheOption=None
    mdtDiskSize=0
    mdtNumDisks=0
    ostStorageSku=Premium_LRS
    ostCacheOption=None
    ostDiskSize=0
    ostNumDisks=0
elif [ "$lustreTier" = "prem" ]; then
    mdsSku=Standard_D8s_v3
    ossSku=Standard_D48s_v3
    mdtStorageSku=Premium_LRS
    mdtCacheOption=ReadWrite
    mdtDiskSize=1024
    mdtNumDisks=2
    ostStorageSku=Premium_LRS
    ostCacheOption=None
    ostDiskSize=1024
    ostNumDisks=6
elif [ "$lustreTier" = "std" ]; then
    mdsSku=Standard_D8s_v3
    ossSku=Standard_D48s_v3
    mdtStorageSku=Standard_LRS
    mdtCacheOption=ReadWrite
    mdtDiskSize=1024
    mdtNumDisks=4
    ostStorageSku=Standard_LRS
    ostCacheOption=None
    ostDiskSize=8192
    ostNumDisks=4
else
    echo "Unknown lustre tier ($lustreTier)."
    exit 1
fi

az deployment group create -g $imageResourceGroup --template-file scripts/azuredeploy.json --parameters \
    name="$name" \
    mdsSku="$mdsSku" \
    ossSku="$ossSku" \
    instanceCount="$instanceCount" \
    rsaPublicKey="$rsaPublicKey" \
    imageResourceGroup="$imageResourceGroup" \
    imageName="$imageName" \
    existingVnetResourceGroupName="$existingVnetResourceGroupName" \
    existingVnetName="$existingVnetName" \
    existingSubnetName="$existingSubnetName" \
    mdtStorageSku="$mdtStorageSku" \
    mdtCacheOption="$mdtCacheOption" \
    mdtDiskSize="$mdtDiskSize" \
    mdtNumDisks="$mdtNumDisks" \
    ostStorageSku="$ostStorageSku" \
    ostCacheOption="$ostCacheOption" \
    ostDiskSize="$ostDiskSize" \
    ostNumDisks="$ostNumDisks" \
    ossDiskSetup="$ossDiskSetup"

