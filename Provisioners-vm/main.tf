

resource "azurerm_resource_group" "test_rg_01" {
  name     = "provisioner-rg"
  location = "West Europe"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "example-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.test_rg_01.location
  resource_group_name = azurerm_resource_group.test_rg_01.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.test_rg_01.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "example" {
  name                = "acceptanceTestPublicIp1"
  resource_group_name = azurerm_resource_group.test_rg_01.name
  location            = azurerm_resource_group.test_rg_01.location
  allocation_method   = "Static"
}

resource "azurerm_network_security_group" "nsg" {
  name                = "acceptanceTestSecurityGroup1"
  location            = azurerm_resource_group.test_rg_01.location
  resource_group_name = azurerm_resource_group.test_rg_01.name

  security_rule {
    name                       = "allow_http"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow_https"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "nic" {
  name                = "example-nic"
  location            = azurerm_resource_group.test_rg_01.location
  resource_group_name = azurerm_resource_group.test_rg_01.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.example.id
  }
}

resource "azurerm_subnet_network_security_group_association" "nsg_association" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_linux_virtual_machine" "test_vm" {
  name                = "example-machine"
  resource_group_name = azurerm_resource_group.test_rg_01.name
  location            = azurerm_resource_group.test_rg_01.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  admin_password      = "Admin@01234"
  disable_password_authentication = false 

  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  connection {
    type        = "ssh"
    host        = azurerm_public_ip.example.ip_address
    user        = "adminuser"
    password    = "Admin@01234"
    timeout     = "2m"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install nginx -y",
      "sudo cp/temp/index.html /var/www/html"
    ]
  }

  # provisioner "file" {
  #   source = "index.html"  //meraleptop
  #   destination = "/temp/index.html" // remote vm
  
  # }
 
  provisioner "local-exec" {
    command = "echo complete > completed.txt"
  }
}
 
