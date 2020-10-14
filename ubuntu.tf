#create a public IP address for the virtual machine
resource "azurerm_public_ip" "ubuntu-pubip" {
  name                = "ubuntu-pubip"
  location            = var.azure_region
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
  domain_name_label   = "ubuntu-${lower(substr(join("", split(":", timestamp())), 8, -1))}"
}

#create the network interface and put it on the proper vlan/subnet
resource "azurerm_network_interface" "ubuntu-ip" {
  name                = "ubuntu-ip"
  location            = var.azure_region
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ubuntu-ipconf"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = azurerm_public_ip.ubuntu-pubip.id
  }
}

#create the actual VM
resource "azurerm_virtual_machine" "ubuntu" {
  name                  = "ubuntu"
  location              = var.azure_region
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.ubuntu-ip.id]
  vm_size               = var.vm_size

  storage_os_disk {
    name              = "ubuntu-osdisk"
    managed_disk_type = "Standard_LRS"
    caching           = "ReadWrite"
    create_option     = "FromImage"
  }
  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_profile {
    computer_name  = "ubuntu"
    admin_username = var.username
    admin_password = var.password
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  connection {
    host     = azurerm_public_ip.ubuntu-pubip.fqdn
    type     = "ssh"
    user     = var.username
    password = var.password
  }

  provisioner "chef" {
    client_options  = ["chef_license '${var.license_accept}'"]
    use_policyfile  = "true"
    policy_name     = var.policy_name
    policy_group    = var.policy_group
    node_name       = var.server_name
    server_url      = var.chef_server_url
    recreate_client = true
    user_name       = var.chef_user_name
    user_key        = file(var.chef_user_key)
    version         = var.chef_client_version

    # If you have a self signed cert on your chef server change this to :verify_none
    ssl_verify_mode = ":verify_peer"
  }
}

output "ubuntu-fqdn" {
  value = azurerm_public_ip.ubuntu-pubip.fqdn
}

