terraform {
  required_providers {
    virtualbox = {
      source = "terra-farm/virtualbox"
      version = "0.2.2-alpha.1"
    }
  }
}

# There are currently no configuration options for the provider itself.

resource "virtualbox_vm" "node" {
  count     = 1
  name      = "node-1"
  image     = "/home/gas/Téléchargement/6ce31aca-ac1f-4bd3-a6ff-5aabde9e3863"
  cpus      = 2
  memory    = "512 mib"
  #user_data = file("${path.module}/user_data")

  network_adapter {
    type           = "bridged"
    host_interface = "enp2s0"
  }
}

output "IPAddr" {
  value = element(virtualbox_vm.node.*.network_adapter.0.ipv4_address, 1)
}
