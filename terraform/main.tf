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
  name      = "kubernetes-worker-02"
  image     = "../images/k8s-node.box"
  cpus      = 1
  memory    = "1 gib"
  #user_data = file("${path.module}/user_data")

  network_adapter {
    type           = "bridged"
    host_interface = "enp4s0"
  }
}

output "IPAddr" {
  value = element(virtualbox_vm.node.*.network_adapter.0.ipv4_address, 1)
}
