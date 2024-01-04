terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.85.0"
    }
  }
}

provider "azurerm" {
 subscription_id = "72fa5383-15d6-4375-8445-e429061bba51"
  tenant_id       = "90f76f03-ef55-4102-a616-5b4235d4b5a7"
  client_id       = "ba169d79-3fae-4592-a5c6-c4d651743ded"
  client_secret   = "2fi8Q~rwUtF0c.J7hoBX~Py6DxUJG2o2EtLYTdfq"
  features {}
}

variable "no_of_instances" {
  type = number 
  description = "Please enter the number of instances"
}
variable "storage_account_name" {
  type = string
  description = "Please enter the storage account name"
}
variable "resource_group_name" {
  type = string
  description = "Please enter the resource group name"
}

locals {
  resource_group = "rg-terra22"
  location = "eastus2"
  vm_name = "testvm"
  Admin_username = "security"
  admin_password = "Twistamain123@"
}

resource "azurerm_resource_group" "resource_group" {
  name = var.resource_group_name
  location = local.location
}

resource "azurerm_storage_account" "storage-account" {
  name                     = var.storage_account_name
  resource_group_name      = local.resource_group
  location                 = local.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  depends_on = [ azurerm_resource_group.resource_group ]
}

resource "azurerm_storage_container" "container-1" {
  name                  = "container01"
  storage_account_name  = var.storage_account_name
  container_access_type = "blob"
  depends_on = [ azurerm_storage_account.storage-account ]
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet"
  address_space       = ["10.0.0.0/16"]
  location            = local.location
  resource_group_name = local.resource_group
  depends_on = [ azurerm_resource_group.resource_group ]
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet"
  resource_group_name  = local.resource_group
  virtual_network_name = "vnet"
  address_prefixes     = ["10.0.0.0/24"]
  depends_on = [ azurerm_virtual_network.vnet ]
}

resource "azurerm_public_ip" "public-ip" {
    count = var.no_of_instances
  name                = format("testvmIP%s",(count.index)+1)
  resource_group_name = local.resource_group
  location            = local.location
  allocation_method   = "Static"
  depends_on = [ azurerm_resource_group.resource_group ]
}

resource "azurerm_network_security_group" "nsg-1" {
  name                = "NSG-1"
  location            = local.location
  resource_group_name = local.resource_group

  security_rule {
    name                       = "rule-1"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  depends_on = [ azurerm_resource_group.resource_group, azurerm_windows_virtual_machine.testvm ]
}

resource "azurerm_network_interface" "NIC" {
    count = var.no_of_instances
  name                = format("testvm-nic%s",(count.index)+1)
  location            = local.location
  resource_group_name = local.resource_group

  ip_configuration {
    name                          = "testconfiguration1"
    subnet_id                     = azurerm_subnet.subnet.id
    public_ip_address_id = azurerm_public_ip.public-ip[count.index].id
    private_ip_address_allocation = "Dynamic"
  }
  depends_on = [ azurerm_virtual_network.vnet, azurerm_public_ip.public-ip]
}
resource "azurerm_windows_virtual_machine" "testvm" {
    count = var.no_of_instances
  name                = format("%s%s",local.vm_name,(count.index)+1)
  resource_group_name = local.resource_group
  location            = local.location
  size                = "Standard_DS1_V2"
  admin_username      = local.Admin_username
  admin_password      = local.admin_password
  network_interface_ids = [ azurerm_network_interface.NIC[count.index].id ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
  depends_on = [ azurerm_network_interface.NIC,
  azurerm_virtual_network.vnet,]
}
