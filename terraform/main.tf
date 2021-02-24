provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "lustre" {
  name = "azlustre"
  location = "northcentralus"
  tags = {
      project = "lustre"
      owner = "ronieuwe"
  }
}

resource "random_id" "storage_gen_name" {
  byte_length = 8
}

resource "azurerm_storage_account" "stor" {
  name                     = "lustre${lower(replace(random_id.storage_gen_name.b64_url, "/[-_=]/", ""))}"
  location                 = azurerm_resource_group.lustre.location
  resource_group_name      = azurerm_resource_group.lustre.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_virtual_network" "lustre" {
  name                = "lustre-net"
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.lustre.location
  resource_group_name = azurerm_resource_group.lustre.name
}

resource "azurerm_subnet" "cluster" {
  name                 = "cluster"
  resource_group_name  = azurerm_resource_group.lustre.name
  virtual_network_name = azurerm_virtual_network.lustre.name
  address_prefixes     = ["10.10.2.0/23"]
}

resource "azurerm_subnet" "client" {
  name                 = "clients"
  resource_group_name  = azurerm_resource_group.lustre.name
  virtual_network_name = azurerm_virtual_network.lustre.name
  address_prefixes     = ["10.10.4.0/23"]
}

## Section for MGS

resource "azurerm_network_interface" "mgs" {
  name                = "lustre-mgs-1-nic"
  location            = azurerm_resource_group.lustre.location
  resource_group_name = azurerm_resource_group.lustre.name

  ip_configuration {
    name                          = "ipconfig-mgs-1-nic"
    subnet_id                     = azurerm_subnet.client.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_managed_disk" "mgs" {
  name                 = "lustre-mgs-1-data"
  location             = azurerm_resource_group.lustre.location
  create_option        = "Empty"
  disk_size_gb         = 32
  resource_group_name  = azurerm_resource_group.lustre.name
  storage_account_type = "Premium_LRS"
}

resource "azurerm_virtual_machine_data_disk_attachment" "mgs" {
  virtual_machine_id = azurerm_linux_virtual_machine.mgs.id
  managed_disk_id    = azurerm_managed_disk.mgs.id
  lun                = 0
  caching            = "None"
}

resource "azurerm_linux_virtual_machine" "mgs" {
  name                  = "lustre-mgs-1"
  location              = azurerm_resource_group.lustre.location
  resource_group_name   = azurerm_resource_group.lustre.name
  network_interface_ids = [ azurerm_network_interface.mgs.id ]
  size                  = "Standard_D8s_v3"

  os_disk {
    name                 = "lustre-mgs-1-os"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "OpenLogic"
    offer     = "CentOS"
    sku       = "7_9"
    version   = "latest"
  }

  computer_name  = "lustre-mgs-1"
  admin_username = "lustre"
  disable_password_authentication = true
  custom_data = base64encode(templatefile("scripts/lustre.tpl", { type = "HEAD", index = 0, diskcount = 1, mgs_ip="0.0.0.0", fs_name = var.lustre-filesystem-name, lustre_version = var.lustre-version }))

  admin_ssh_key {
    username   = "lustre"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.stor.primary_blob_endpoint
  }
}

## Section for OSS

resource "azurerm_network_interface" "oss" {
  name                = "lustre-oss-nic${count.index}"
  location            = azurerm_resource_group.lustre.location
  resource_group_name = azurerm_resource_group.lustre.name
  count               = var.oss-nodes.total

  ip_configuration {
    name                          = "ipconfig-oss-nic-${count.index}"
    subnet_id                     = azurerm_subnet.client.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "oss" {
  count                 = var.oss-nodes.total
  name                  = "lustre-oss-${count.index}"
  location              = azurerm_resource_group.lustre.location
  resource_group_name   = azurerm_resource_group.lustre.name
  network_interface_ids = [element(azurerm_network_interface.oss.*.id, count.index)]
  size                  = var.oss-nodes.sku

  os_disk {
    name                 = "lustre-oss-${count.index}-os"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "OpenLogic"
    offer     = "CentOS"
    sku       = "7_9"
    version   = "latest"
  }

  computer_name  = "lustre-oss-${count.index}"
  admin_username = "lustre"
  disable_password_authentication = true
  custom_data = base64encode(templatefile("scripts/lustre.tpl", { type = "OSS", index = count.index, diskcount = var.oss-nodes-disks.total, mgs_ip=azurerm_network_interface.mgs.private_ip_address, fs_name = var.lustre-filesystem-name, lustre_version = var.lustre-version }))
  
  admin_ssh_key {
    username   = "lustre"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.stor.primary_blob_endpoint
  }

  depends_on = [ 
    azurerm_network_interface.mgs,
    azurerm_linux_virtual_machine.mgs
  ]
}

# Make map

locals {
  vm_datadiskdisk_count_map = { for k in range(0, var.oss-nodes.total)  : k => var.oss-nodes-disks.total }
  luns                      = { for k in local.datadisk_lun_map : k.datadisk_name => k.lun }
  datadisk_lun_map = flatten([
    for vm_name, count in local.vm_datadiskdisk_count_map : [
      for i in range(count) : {
        datadisk_name = format("lustre-oss-%s-disk%02d", vm_name, i)
        lun           = i
      }
    ]
  ])
}

# Disk themselves, P30 disks, 200MB/s, 5000 IOPS. We attach them in the next step (post VM provision)
resource "azurerm_managed_disk" "managed_disk" {
  for_each             = toset([for j in local.datadisk_lun_map : j.datadisk_name])
  name                 = each.key
  location             = azurerm_resource_group.lustre.location
  resource_group_name  = azurerm_resource_group.lustre.name
  storage_account_type = var.oss-nodes-disks.sku
  create_option        = "Empty"
  disk_size_gb         = var.oss-nodes-disks.size

}

resource "azurerm_virtual_machine_data_disk_attachment" "managed_disk_attach" {
  for_each           = toset([for j in local.datadisk_lun_map : j.datadisk_name])
  managed_disk_id    = azurerm_managed_disk.managed_disk[each.key].id
  virtual_machine_id = azurerm_linux_virtual_machine.oss[tonumber(element(split("-", each.key), 2))].id
  lun                = lookup(local.luns, each.key)
  caching            = "None"
}

## Section jump server

resource "azurerm_network_interface" "jump" {
  name                = "lustre-jump-server-nic"
  location            = azurerm_resource_group.lustre.location
  resource_group_name = azurerm_resource_group.lustre.name

  ip_configuration {
    name                          = "ipconfig-jump-server-nic"
    subnet_id                     = azurerm_subnet.client.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jump.id
  }
}

resource "azurerm_public_ip" "jump" {
  name                = "lustre-jump-server-pip"
  resource_group_name = azurerm_resource_group.lustre.name
  location            = azurerm_resource_group.lustre.location
  allocation_method   = "Dynamic"
}

resource "azurerm_linux_virtual_machine" "jump" {
  name                  = "lustre-jump-server"
  location              = azurerm_resource_group.lustre.location
  resource_group_name   = azurerm_resource_group.lustre.name
  network_interface_ids = [ azurerm_network_interface.jump.id ]
  size                  = "Standard_D2s_v3"

  os_disk {
    name                 = "lustre-jump-server-os"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "OpenLogic"
    offer     = "CentOS"
    sku       = "7_9"
    version   = "latest"
  }

  computer_name  = "lustre-jump-server"
  admin_username = "lustre"
  disable_password_authentication = true
  custom_data = base64encode(templatefile("scripts/lustre.tpl", { type = "CLIENT", index = 0, diskcount = 0, mgs_ip=azurerm_network_interface.mgs.private_ip_address, fs_name = var.lustre-filesystem-name, lustre_version = var.lustre-version }))
  
  admin_ssh_key {
    username   = "lustre"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.stor.primary_blob_endpoint
  }

  depends_on = [ 
    azurerm_network_interface.mgs,
    azurerm_linux_virtual_machine.mgs
  ]
}