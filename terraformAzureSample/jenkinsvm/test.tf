## Azure VM Standard_A2 ready for Jenkins installation

provider "azurerm" {}

resource "azurerm_resource_group" "myterraformgroup" {
  name     = "hmis19jenkins-rg"
  location = "eastus2"          ## "westus"

  tags {
    environment = "Terraform Demo"
  }
}

resource "azurerm_virtual_network" "myterraformnetwork" {
  name                = "${azurerm_resource_group.myterraformgroup.name}-net"
  address_space       = ["10.0.0.0/16"]
  location            = "${azurerm_resource_group.myterraformgroup.location}"
  resource_group_name = "${azurerm_resource_group.myterraformgroup.name}"

  tags {
    environment = "Terraform Demo"
  }
}

resource "azurerm_subnet" "myterraformsubnet" {
  name                 = "${azurerm_resource_group.myterraformgroup.name}-subnet"
  resource_group_name  = "${azurerm_resource_group.myterraformgroup.name}"
  virtual_network_name = "${azurerm_virtual_network.myterraformnetwork.name}"
  address_prefix       = "10.0.2.0/24"
}

resource "azurerm_public_ip" "myterraformpublicip" {
  name                         = "${azurerm_virtual_network.myterraformnetwork.name}-publicIP"
  location                     = "${azurerm_resource_group.myterraformgroup.location}"
  resource_group_name          = "${azurerm_resource_group.myterraformgroup.name}"
  public_ip_address_allocation = "dynamic"
  domain_name_label            = "hmis19tf"

  tags {
    environment = "Terraform Demo"
  }
}

resource "azurerm_network_security_group" "temyterraformpublicipnsg" {
  name                = "${azurerm_virtual_network.myterraformnetwork.name}-networkSecurityGroup"
  location            = "${azurerm_resource_group.myterraformgroup.location}"
  resource_group_name = "${azurerm_resource_group.myterraformgroup.name}"

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags {
    environment = "Terraform Demo"
  }
}

resource "azurerm_network_interface" "myterraformnic" {
  name                = "${azurerm_virtual_network.myterraformnetwork.name}-myNIC"
  location            = "${azurerm_resource_group.myterraformgroup.location}"
  resource_group_name = "${azurerm_resource_group.myterraformgroup.name}"

  ip_configuration {
    name                          = "myNicConfiguration"
    subnet_id                     = "${azurerm_subnet.myterraformsubnet.id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = "${azurerm_public_ip.myterraformpublicip.id}"
  }

  tags {
    environment = "Terraform Demo"
  }
}

resource "random_id" "randomId" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = "${azurerm_resource_group.myterraformgroup.name}"
  }

  byte_length = 8
}

resource "azurerm_storage_account" "mystorageaccount" {
  name                     = "diag${random_id.randomId.hex}"
  resource_group_name      = "${azurerm_resource_group.myterraformgroup.name}"
  location                 = "${azurerm_resource_group.myterraformgroup.location}"
  account_replication_type = "LRS"
  account_tier             = "Standard"

  tags {
    environment = "Terraform Demo"
  }
}

resource "azurerm_virtual_machine" "myterraformvm" {
  name                  = "${azurerm_resource_group.myterraformgroup.name}-vm"
  location              = "${azurerm_resource_group.myterraformgroup.location}"
  resource_group_name   = "${azurerm_resource_group.myterraformgroup.name}"
  network_interface_ids = ["${azurerm_network_interface.myterraformnic.id}"]
  vm_size               = "Standard_A2"                                         ## "Standard_DS1_v2"

  storage_os_disk {
    name              = "myOsDisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS" # "Premium_LRS"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_profile {
    computer_name  = "${azurerm_resource_group.myterraformgroup.name}-vm"
    admin_username = "azureuser"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/azureuser/.ssh/authorized_keys"
      key_data = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDC6J779/+3i9yO7/VaIH2ujqhPU40QNoXZKtLGjqHWjr88XPTKuunvVitpWnaNDQTr2V/yEJbgA+g4Dicj2FAr35S+YkuWsyrkqaF+lESlhjGCYgaPe6zRYgUdv9GT4yWgfWsu+NEbi/BxsFoWDCDPoRpVEda39AQRzNLhgwcXmRiIRyj6Sb+cEBIEGHbbwnXHzXGt0NRcAGsrfzlUbic91TBtY1u0bYpfwAEayAJ7jA0mEBgri1RauhdFevTj6dqyUY02PxAqZZZp5DlZKpwMC+lxW9/QyoC6ziwfHo4uHVuM6GFl3/EMQfvH2+5HAKj1DROfMfchjfGCiDm+iw3+DOFRNBXglPierJwfbW5+igSGp3pd4qfNxUNDl1lclFvPxDPAYcw6QhddPNOcVUYbVuzC92+nU2ij4fkcRjdbN4J/pwLgHic3PbVfgn1O8UZV+1tMQNXf5fcW4sLyskORjOIGZRULhuU9yAA3Etz1Db/JgYyIpwAYH2RaVfThUx3Nw+GAaw2jIIERYLkRvH4lSgeC/iNb+y5HHzkraw1k5SpkZeAWhIkADeZgubQlahJD2eIZjpjq6iZipyFuGCN+dwXrI17vrJDoi/jdbn+8/kU9ynJpilPB/ZUdTiVMZGz42OvlFsGkNt5WmM3hZHeq/nHCOizgWVVNYPjE0Z9kKw== juanrdzbaeza@gmail.com"
    }
  }

  boot_diagnostics {
    enabled     = "true"
    storage_uri = "${azurerm_storage_account.mystorageaccount.primary_blob_endpoint}"
  }

  tags {
    environment = "Terraform Demo"
  }
}
