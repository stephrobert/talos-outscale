packer {
  required_plugins {
    outscale = {
      source  = "github.com/outscale/outscale"
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
  default = "Talos-GPU"
}

variable "vm_type" {
  type    = string
  default = "tinav6.c2r4p1"  # VM légère pour construire l'image
}

variable "source_omi" {
  type        = string
  default     = ""
  description = "OMI Ubuntu 22.04 pour la construction (ex: ami-xxxxxxxx)"
}

variable "talos_version" {
  type    = string
  default = "v1.11.5"
}

variable "volume_size" {
  type    = number
  default = 20  # GB - peut être augmenté si besoin
}

variable "ssh_username" {
  type    = string
  default = "outscale"
}

variable "image_type" {
  type        = string
  default     = "universal"
  description = "Type d'image GPU: 'universal' (avec fabricmanager pour NVLink/HGX) ou 'simple' (sans fabricmanager)"

  validation {
    condition     = contains(["universal", "simple"], var.image_type)
    error_message = "Le type d'image doit être 'universal' ou 'simple'."
  }
}

variable "schematic_id" {
  type        = string
  default     = ""
  description = "Schematic ID Talos Image Factory (laisser vide pour génération automatique)"
}

# Tags
locals {
  common_tags = {
    Project   = "talos-gpu"
    Version   = var.talos_version
    ImageType = var.image_type
    ManagedBy = "packer"
  }

  # Extensions selon le type d'image
  # Utilise les nouvelles extensions avec suffixe -production (driver 570.195.03)
  # nvidia-fabricmanager-production est inclus pour le support NVLink/HGX
  extensions = var.image_type == "universal" ? [
    "siderolabs/nvidia-open-gpu-kernel-modules-production",
    "siderolabs/nvidia-container-toolkit-production",
    "siderolabs/nvidia-fabricmanager-production"
  ] : [
    "siderolabs/nvidia-open-gpu-kernel-modules-production",
    "siderolabs/nvidia-container-toolkit-production"
  ]
}

# Builder « bsusurrogate » : il attache un volume BSU vierge, on l'approvisionne,
# puis Packer snapshotte et enregistre l'OMI à partir de ce volume.
source "outscale-bsusurrogate" "builder" {
  region  = var.region
  vm_type = var.vm_type

  # Filtre pour trouver l'OMI Ubuntu 22.04 la plus récente
  source_omi_filter {
    filters = {
      image_name        = "Ubuntu-22.04-*"
      root_device_type  = "ebs"
      virtualization_type = "hvm"
    }
    most_recent = true
    owners      = ["Outscale"]
  }

  # Si source_omi est fourni, il sera utilisé à la place du filtre
  # source_omi = var.source_omi

  launch_block_device_mappings {
    delete_on_vm_deletion = true
    device_name           = "/dev/xvdf"
    volume_size           = var.volume_size
    volume_type           = "gp2"
  }

  omi_name        = "${var.omi_name}-${var.image_type}-${var.talos_version}-${formatdate("YYYYMMDD-hhmmss", timestamp())}"
  omi_description = "Talos Linux ${var.talos_version} with NVIDIA GPU extensions (${var.image_type}) - Built with Packer"
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
  name    = "talos-gpu-outscale"
  sources = ["source.outscale-bsusurrogate.builder"]

  provisioner "ansible" {
    user = var.ssh_username
    playbook_file = "provision/playbook-gpu.yaml"
    ansible_env_vars = [
      "ANSIBLE_SCP_EXTRA_ARGS=-O",
    ]
    extra_arguments = [
      "--extra-vars", "talos_version=${var.talos_version}",
      "--extra-vars", "image_type=${var.image_type}"
    ]
  }

  # Sauvegarder les informations de build
  post-processor "manifest" {
    output     = "manifest-gpu-${var.image_type}.json"
    strip_path = true
    custom_data = {
      talos_version = var.talos_version
      image_type    = var.image_type
      extensions    = jsonencode(local.extensions)
      build_time    = timestamp()
    }
  }
}
