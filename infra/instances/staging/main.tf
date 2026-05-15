terraform {
  backend "remote" {
    organization = "glich-stream"

    workspaces {
      name = "ci-cd-staging"
    }
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.110"
    }

    random = {
      source = "hashicorp/random"
      version = "3.1.0"
    }
  }

  required_version = ">= 0.15.0"
}

provider "aws" {
}

provider "azurerm" {
  features {}
}

variable "staging_public_key" {
  description = "Staging environment public key value"
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

resource "random_id" "server" {
  keepers = {
    # Generate a new id each time we switch to a new image id
    image_id = "${var.base_image_id}"
  }

  byte_length = 8
}

resource "azurerm_resource_group" "staging" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "staging" {
  name                = "staging-vnet"
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.staging.location
  resource_group_name = azurerm_resource_group.staging.name
}

resource "azurerm_subnet" "staging" {
  name                 = "staging-subnet"
  resource_group_name  = azurerm_resource_group.staging.name
  virtual_network_name = azurerm_virtual_network.staging.name
  address_prefixes     = ["10.10.1.0/24"]
}

resource "azurerm_network_security_group" "staging" {
  name                = "staging-nsg"
  location            = azurerm_resource_group.staging.location
  resource_group_name = azurerm_resource_group.staging.name

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

# This is the main staging environment. We will deploy to this the changes
# to the main branch before deploying to the production environment.
resource "azurerm_public_ip" "staging" {
  name                = "staging-pip-${random_id.server.hex}"
  location            = azurerm_resource_group.staging.location
  resource_group_name = azurerm_resource_group.staging.name
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "staging" {
  name                = "staging-nic-${random_id.server.hex}"
  location            = azurerm_resource_group.staging.location
  resource_group_name = azurerm_resource_group.staging.name

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.staging.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.staging.id
  }
}

resource "azurerm_network_interface_security_group_association" "staging" {
  network_interface_id      = azurerm_network_interface.staging.id
  network_security_group_id = azurerm_network_security_group.staging.id
}

# This is the main staging environment. We will deploy to this the changes
# to the main branch before deploying to the production environment.
resource "azurerm_linux_virtual_machine" "staging_cicd_demo" {
  name                = "staging-cicd-${random_id.server.hex}"
  resource_group_name = azurerm_resource_group.staging.name
  location            = azurerm_resource_group.staging.location
  size                = "Standard_B1s"
  admin_username      = var.admin_username
  network_interface_ids = [
    azurerm_network_interface.staging.id
  ]
  source_image_id = var.base_image_id

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.staging_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
}

output "staging_public_ip" {
  value = azurerm_public_ip.staging.ip_address
}
