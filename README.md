# azlustre

## Deploy a Lustre filesystem on Azure  

Click the button below to get started:

[![Deploy to Azure](https://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazlustre%2Fmaster%2Fazuredeploy.json)

### General Parameters

| Parameter                     | Description                                                                        |
|-------------------------------|------------------------------------------------------------------------------------|
| name                          | The name for the Lustre filesystem                                                 |
| mdsSku                        | The SKU for the MDS VMs                                                            |
| ossSku                        | The SKU for the OSS VMs                                                            |
| instanceCount                 | The number of OSS VMs                                                              |
| rsaPublicKey                  | The RSA public key to access the VMs                                               |
| existingVnetResourceGroupName | The resource group containing the VNET where Lustre is to be deployed              |
| existingVnetName              | The name of the VNET where Lustre is to be deployed                                |
| existingSubnetName            | The name of the subnet where Lustre is to be deployed                              |
| mdtStorageSku                 | The SKU to use for the MDT disks                                                   |
| mdtCacheOption                | The caching option for the MDT disks (e.g. `None` or `ReadWrite`)                  |
| mdtDiskSize                   | The size of each MDT disk                                                          |
| mdtNumDisks                   | The number of disks in the MDT RAID (set to `0` to use the VM ephemeral disks)     |
| ostStorageSku                 | The SKU to use for OST disks                                                       |
| ostCacheOption                | The caching option for the OST disks (e.g. `None` or `ReadWrite`)                  |
| ostDiskSize                   | The size of each OST disk                                                          |
| ostNumDisks                   | The number of OST disks per OSS (set to `0` to use the VM ephemeral disks)         |
| ossDiskSetup                  | Either `separate` where each disk is an OST or `raid` to combine into a single OST |

### Hierarchical Storage Management (HSM) Parameters

The additional parameters can be used to enable HSM for the Lustre deployment.

| Parameter        | Description                         |
|------------------|-------------------------------------|
| storageAccount   | The storage account to use for HSM  |
| storageContainer | The container name to use           |
| storageSas       | The SAS key for the storage account |

The SAS key requires read, write, list and delete permissions.  Be aware when choosing an expiry time that it will be stored on the OSS VMs and used for the HSM operations (and HSM will stop working once it expires).  Here is an example of creating a SAS key with a 1 month expiry using the Azure CLI:

```
# TODO: set the account name and container name below
account_name=
container_name=

start_date=$(date +"%Y-%m-%dT%H:%M:%SZ")
expiry_date=$(date +"%Y-%m-%dT%H:%M:%SZ" --date "next month")

az storage container generate-sas \
   --account-name $account_name \
   --name $container_name \
   --permissions rwld \
   --start $start_date \
   --expiry $expiry_date \
   -o tsv
```

### Logging Parameters

The additional parameters can be used to log metrics for the Lustre deployment.  Be aware this does require a log analytics workspace to be set up.  Leave this empty to disable logging.

| Parameter               | Description                           |
|-------------------------|---------------------------------------|
| logAnalyticsWorkspaceId | The log analytics workspace id to use |
| logAnalyticsKey         | The key for the log analytics account |


## Example configurations

When creating a Lustre configuration you pay attention to the following:

* The [expected network bandwidth](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-machine-network-throughput) for the VM type
* The max uncached disk throughput when using managed disks
* The throughput for the [managed disks](https://azure.microsoft.com/en-gb/pricing/details/managed-disks/)

This section provides options for three types of setup:

1. **Ephemeral**
   This is the cheapest option and uses local disks to the VMs.  This can also provide the lowest latency as the physical storage resides on the host.  Any VM failure will result in data loss but is a good option for scratch storage.

   Size: 7.6 TB per OSS

   Expected performance: 1600 MB/s per OSS (limited by NIC on VM)
2. **Persistent Premium** 
   This option uses premium disks attached to the VMs.  A VM failing will not result in data loss.

   Size: 6 TB per OSS

   Expected performance: 1152 MB/s per OSS (limited by uncached disk throughput)
3. **Persistent Standard**
   This option uses standard disks attached to the VMs.  This requires relatively higher storage per OSS since the larger disks are needed in order to maximise the bandwidth to storage for a VM.

   Size: 32 TB per OSS

   Expected performance: 1152 MB/s per OSS (limited by uncached disk throughput)

These are the parameters that can be used when deploying:

| Parameter      | Ephemeral        | Persistent Premium | Persistent Standard |
|----------------|------------------|--------------------|---------------------|
| mdsSku         | Standard_L8s_v2  | Standard_D8_v3     | Standard_D8_v3      |
| ossSku         | Standard_L48s_v2 | Standard_D48_v3    | Standard_D48_v3     |
| mdtStorageSku  | Premium_LRS      | Premium_LRS        | Standard_LRS        |
| mdtCacheOption | None             | ReadWrite          | ReadWrite           |
| mdtDiskSize    | 0                | 1024               | 1024                |
| mdtNumDisks    | 0                | 2                  | 2                   |
| ostStorageSku  | Premium_LRS      | Premium_LRS        | Standard_LRS        |
| ostCacheOption | None             | None               | None                |
| ostDiskSize    | 0                | 1024               | 8192                |
| ostNumDisks    | 0                | 6                  | 4                   |


## Developer notes

This project includes the following:

* An [ARM template](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/) to deploy a Lustre cluster using the image.
* A [packer](https://www.packer.io/) script to build an image with the Lustre packages installed.
* A [Terraform template](terraform/README.md) to deploy a Lustre cluster automatically based on a marketplace image.

The Lustre setup scripts are modified versions from the [AzureHPC](https://github.com/Azure/azurehpc) project.  

### Lustre ARM Template

The ARM template performs the installation with [cloud init](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/using-cloud-init) where the installation scripts are embedded.  The `azuredeploy.json` includes the embedded scripts but the repo includes script to create this from the `azuredeploy_template.json`.

The `cloud-ci.sh` script performs this step and the `build.sh` executes this with the parameters used for the currently distributed ARM template in the repository.  The scripts are embedded as a self-extracting compressed tar archive to be run by cloud-init.  The [makeself](https://makeself.io/) tool is required for this step.

*Rebuilding is only required when making changes to the scripts.*

### Packer scripts

The ARM templates in this repository use the [AzureHPC Lustre marketplace image](https://azuremarketplace.microsoft.com/en-us/marketplace/apps/azhpc.azurehpc-lustre).  This image has been created with the packer scripts provided in this repository.  

Packer is required for the build so download the latest version for your operating system from https://www.packer.io.  It is distributed as a single file so just put it somewhere that is in your `PATH`.  Go into the packer directory:

```
cd azlustre/packer
```

The following options are required to build:

| Variable            | Description                                         |
|---------------------|-----------------------------------------------------|
| var_subscription_id | Azure subscription ID                               |
| var_tenant_id       | Tenant ID for the service principal                 |
| var_client_id       | Client ID for the service principal                 |
| var_client_secret   | Client password for the service principal           |
| var_resource_group  | The resource group to put the image in (must exist) |
| var_image           | The image name to create                            |

These can be read by packer from a JSON file.  Use this template to create `options.json` and populate the fields:

```
{
    "var_subscription_id": "",
    "var_tenant_id": "",
    "var_client_id": "",
    "var_client_secret": "",
    "var_resource_group": "",
    "var_image": "azurehpc-lustre-2.12.5"
}
```

Use the following command to build with packer:

```
packer build -var-file=options.json azurehpc-lustre-2.12.5.json
```

Once this successfully completes the image will be available (although the ARM template will need to be modified to use this new image).

