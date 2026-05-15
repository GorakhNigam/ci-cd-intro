terraform {
  backend "remote" {
    organization = "glich-stream"

    workspaces {
      name = "ci-cd-production"
    }
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.110"
    }
  }

  required_version = ">= 0.15.0"
}

provider "azurerm" {
  features {}
}

variable "production_public_key" {
  description = "Production environment public key value"
  type        = string
}

variable "base_image_id" {
  description = "Azure managed image ID built by Packer"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Azure resource group name"
  type        = string
}

variable "admin_username" {
  description = "Linux VM admin username"
  type        = string
}

resource "azurerm_resource_group" "production" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "production" {
  name                = "production-vnet"
  address_space       = ["10.20.0.0/16"]
  location            = azurerm_resource_group.production.location
  resource_group_name = azurerm_resource_group.production.name
}

resource "azurerm_subnet" "production" {
  name                 = "production-subnet"
  resource_group_name  = azurerm_resource_group.production.name
  virtual_network_name = azurerm_virtual_network.production.name
  address_prefixes     = ["10.20.1.0/24"]
}

resource "azurerm_network_security_group" "production" {
  name                = "production-nsg"
  location            = azurerm_resource_group.production.location
  resource_group_name = azurerm_resource_group.production.name

  security_rule {
    name                       = "allow-ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "production" {
  name                = "production-pip"
  location            = azurerm_resource_group.production.location
  resource_group_name = azurerm_resource_group.production.name
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "production" {
  name                = "production-nic"
  location            = azurerm_resource_group.production.location
  resource_group_name = azurerm_resource_group.production.name

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.production.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.production.id
  }
}

resource "azurerm_network_interface_security_group_association" "production" {
  network_interface_id      = azurerm_network_interface.production.id
  network_security_group_id = azurerm_network_security_group.production.id
}

resource "azurerm_linux_virtual_machine" "production_cicd_demo" {
  name                = "production-cicd"
  resource_group_name = azurerm_resource_group.production.name
  location            = azurerm_resource_group.production.location
  size                = "Standard_B1s"
  admin_username      = var.admin_username
  network_interface_ids = [
    azurerm_network_interface.production.id
  ]
  source_image_id = var.base_image_id

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.production_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
}

output "production_public_ip" {
  value = azurerm_public_ip.production.ip_address
}
