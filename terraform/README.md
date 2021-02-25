# Terraform templates for deploying Lustre on Azure

**These templates are still being actively developed.**

## Introduction

These templates can be used to built a ready to go Lustre cluster on Azure compute. The goal is to have templates that provide low friction and make it easy to start using Lustre for workloads like SAS.

What this template accomplishes:

- Sets up a MGS and MDS node with a P30 disk attached to it
- Sets up multiple OSS nodes with one more disks attached to it. Configured with mdadm they are exposed as OSS nodes to the MGS
- Sets up a jumpbox that has the Lustre filesystem automatically mounted

The default sizing is using 2x `Standard_D32s_v3` with 4x Premium P30 disks 1TB disks. This yields 4TB of Lustre per OSS node with 3.8TB usable for a total of 7.6TB. Sizing for Lustre is very important and our recommendation is to scale out before scaling up. For example, a cluster with 12x `Standard_D32s_v3` machines can drive more throughput than a cluster with 6x `Standard_D64s_v3` machines. When using larger files do consider striping data to remove some dependencies on specific nodes being a bottleneck.

This deployment uses your local SSH keys to set up the access, copying your public key to MDS, OSS and jumpbox.

## Variables

You can specify variables in `variables.tf` to customize your deployment. The following variables are currently provided:

| Name of variable       | Description of variable                                              |
|------------------------|----------------------------------------------------------------------|
| oss-nodes.sku          | The VM type for the OSS (data) nodes to use                          |
| oss-nodes.total        | Total number of OSS (data) VMs that will be created for Lustre       |
| oss-nodes-disks.size   | Size of the disk to use, always use full disk size provided by Azure |
| oss-nodes-disks.sku    | Premium_LRS, Standard_LRS, StandardSSD_LRS                           |
| oss-nodes-disks.total  | Total disks is total size of per node data (total*size)              |
| lustre-filesystem-name | The name of te filesystem to mount (ip@tcp:/{fsname})                |
| lustre-version         | Version of Lustre to use, we tested with 2.12.6                      |

## How to deploy

1. Run `az login`
2. In the directory, run `terraform plan`
3. Apply the plan using `terraform apply -parallelism=30` you can change the parallelism. A value of $oss_nodes * $disks_per_oss is recommended (e.g. 12x4 => 48) to accelerate deployment of all the disks for the VMs.
4. Wait for Terraform to complete and 5 minutes later run `az vm list-ip-addresses -o table` and take note of the public IP address of the jumpbox.
5. Use an SSH client to connect to the jumpbox with `ssh lustre@<ip>` and check out the lustre filesystem on `/lustre` or checkout `lfs df -h`

To SSH to the OSS or MGS nodes, please scp/sftp your private key to the jumpbox and hop from there to the node.

Recommended Lustre client tuning for optimal performance is:

```bash
lctl set_param mdc.*.max_rpcs_in_flight=128 osc.*.max_rpcs_in_flight=16 osc.*.max_dirty_mb=1024 llite.*.max_read_ahead_mb=2048 osc.*.checksums=0  llite.*.max_read_ahead_per_file_mb=256
```

## Goals/plans moving forward

1. Make these templates more modular so that you can drop in other existing components much easier (e.g. existing VNet and adding Lustre clients or OSS nodes)
2. Setup HSM and deploy a copytool on the Jumpbox to move data in and out of Lustre on demand
3. Add High Availability options to MSG and MDS nodes.
4. Add High Availability options to OSS nodes.
5. Integrate LogAnalytics
6. Provide some standard t-shirt size variable set ups
7. Add an introduction to Lustre for non-Lustre people
