variable "oss-nodes" {
  description = "The number of OSS nodes"
  default = 4
}

variable "oss-nodes-disks" {
  description = "The number of OSS disks per node"
  default = 4
}

variable "lustre-filesystem-name" {
  description = "Name of the filesystem to create on top of Lustre"
  default = "lustrefs"
}

variable "lustre-version" {
  description = "Version of Lustre to use - check https://downloads.whamcloud.com/public/lustre/"
  default = "2.12.6"
}