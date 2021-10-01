#!/bin/bash

# arg: $1 = storage account
# arg: $2 = storage sas
# arg: $3 = storage container
# arg: $3 = lfs mount
# arg: $4 = lustre mount (default=/lustre)
storage_account="$1"
storage_sas="$2"
storage_container="$3"
lfs_mount=${4:-/lustre}

cd $lfs_mount
export STORAGE_SAS="?$storage_sas"
/sbin/azure-import -account ${storage_account} -container ${storage_container}

