variable "oss-nodes" {
  description = "The number and size of OSS nodes"
  type = object({
    sku   = string
    total = number
  })
  default = { # Standard is a P30 disk
    sku   = "Standard_D32s_v3"    
    total = 2
  }
  
}

variable "oss-nodes-disks" {
  description = "The SKU, size and IOPS of disktype to use. Standard_LRS=HDDs (S), StandardSSD_LRS=SSDs (E), Premium_LRS=SSDs (P)"
  type = object({
    size  = number
    sku   = string
    total = number
  })
  default = { # Default value is a P30 disk
    size  = 1024
    sku   = "Premium_LRS"
    total = 4
  }
}

variable "lustre-filesystem-name" {
  description = "Name of the filesystem to create on top of Lustre"
  default = "lustrefs"
}

variable "lustre-version" {
  description = "Version of Lustre to use - check https://downloads.whamcloud.com/public/lustre/"
  default = "2.12.6"
}