packer {
  required_plugins {
    outscale = {
      source  = "github.com/outscale/outscale"
      version = "~> 1"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = "~> 1"
    }
  }
}

variable "region" {
  type    = string
  default = "eu-west-2"  # ou cloudgouv-eu-west-1
}

variable "omi_name" {
  type    = string
  default = "Talos-Outscale"
}

variable "vm_type" {
  type    = string
  default = "tinav6.c4r8p2"  # ajuster
}

variable "source_omi" {
  type = string  # ex: une petite Ubuntu LTS
}

variable "talos_version" {
  type    = string
  default = "v1.10.6"
}

variable "volume_size" {
  type    = number
  default = 20  # GB
}

variable "ssh_username" {
  type    = string
  default = "outscale"
}

# Plus besoin de schematic_id en variable, il est récupéré dynamiquement par Ansible

# Tags
locals {
  common_tags = {
    Project = "talos"
    version = var.talos_version
    ManagedBy = "packer"
  }
}

# Builder « bsusurrogate » : il attache un volume BSU vierge, on l’approvisionne,
# puis Packer snapshotte et enregistre l’OMI à partir de ce volume.
source "outscale-bsusurrogate" "builder" {
  region     = var.region
  vm_type    = var.vm_type
  source_omi = var.source_omi

  launch_block_device_mappings {
    delete_on_vm_deletion = true
    device_name           = "/dev/xvdf"
    volume_size           = var.volume_size
    volume_type           = "gp2"
  }

  omi_name        = "${var.omi_name}-${var.talos_version}-${formatdate("YYYYMMDD-hhmmss", timestamp())}"
  omi_description = "Talos Linux ${var.talos_version} - Built with Packer/Ansible"
  tags            = local.common_tags

  omi_root_device {
    delete_on_vm_deletion = true
    device_name           = "/dev/sda1"
    source_device_name    = "/dev/xvdf"
    volume_size           = var.volume_size
    volume_type           = "gp2"
  }

  ssh_interface = "public_ip"
  ssh_username  = var.ssh_username
  communicator  = "ssh"
}

build {
  name    = "talos-outscale"
  sources = ["source.outscale-bsusurrogate.builder"]

  provisioner "ansible" {
    user = var.ssh_username
    playbook_file = "provision/playbook.yaml"
    ansible_env_vars = [
      "ANSIBLE_SCP_EXTRA_ARGS=-O",
    ]
  }
}
