# Data source pour trouver l'image Ubuntu pour le bastion
# Note: Ajustez le filtre selon les images disponibles dans votre région
data "outscale_images" "ubuntu" {
  filter {
    name   = "image_names"
    values = ["Ubuntu-22.04-*"]
  }

  filter {
    name   = "account_aliases"
    values = ["Outscale"]
  }
}

# Data source pour trouver l'image Talos
data "outscale_images" "talos" {
  filter {
    name   = "image_names"
    values = ["Talos-${var.talos_version}-*"]
  }
}

locals {
  bastion_image_id = var.bastion_image_id != "" ? var.bastion_image_id : (length(data.outscale_images.ubuntu.images) > 0 ? data.outscale_images.ubuntu.images[0].image_id : "")
  talos_image_id   = var.talos_image_id != "" ? var.talos_image_id : (length(data.outscale_images.talos.images) > 0 ? data.outscale_images.talos.images[0].image_id : "")

  # Subnets pour distribution multi-AZ
  kubernetes_subnets = compact([
    outscale_subnet.kubernetes_az_a.subnet_id,
    var.enable_multi_az && length(outscale_subnet.kubernetes_az_b) > 0 ? outscale_subnet.kubernetes_az_b[0].subnet_id : "",
    var.enable_multi_az && length(outscale_subnet.kubernetes_az_c) > 0 ? outscale_subnet.kubernetes_az_c[0].subnet_id : ""
  ])
}

# User data pour le bastion
locals {
  bastion_user_data = <<-EOF
    #!/bin/bash
    set -e

    # Mise à jour système
    apt-get update
    apt-get upgrade -y

    # Installation des outils
    apt-get install -y curl jq wget python3-pip unzip git

    # Installer osc-cli
    pip3 install osc-sdk

    # Installer talosctl
    curl -sL https://talos.dev/install | sh

    # Installer kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    mv kubectl /usr/local/bin/

    # Installer Helm
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

    # Installer bash-completion
    apt-get install -y bash-completion
    kubectl completion bash | tee /etc/bash_completion.d/kubectl > /dev/null
    talosctl completion bash | tee /etc/bash_completion.d/talosctl > /dev/null
    helm completion bash | tee /etc/bash_completion.d/helm > /dev/null

    # Message de bienvenue
    cat > /etc/motd <<MOTD
    ================================
    Bastion ${var.cluster_name}
    ================================

    Outils installés:
    - talosctl (Talos CLI)
    - kubectl (Kubernetes CLI)
    - helm (Kubernetes Package Manager)
    - osc-cli (Outscale CLI)

    ================================
    MOTD
  EOF
}

# VM Bastion
resource "outscale_vm" "bastion" {
  image_id           = local.bastion_image_id
  vm_type            = var.bastion_vm_type
  keypair_name       = outscale_keypair.main.keypair_name
  security_group_ids = [outscale_security_group.bastion.security_group_id]
  subnet_id          = outscale_subnet.bastion.subnet_id
  user_data          = base64encode(local.bastion_user_data)

  block_device_mappings {
    device_name = "/dev/sda1"
    bsu {
      volume_size           = 20
      volume_type           = "gp2"
      delete_on_vm_deletion = true
    }
  }

  private_ips = ["10.100.1.10"]

  tags {
    key   = "Name"
    value = "${var.cluster_name}-bastion"
  }

  tags {
    key   = "Cluster"
    value = var.cluster_name
  }

  tags {
    key   = "Environment"
    value = var.environment
  }

  tags {
    key   = "Role"
    value = "Bastion"
  }
}

# IP publique pour le bastion
resource "outscale_public_ip" "bastion" {
  tags {
    key   = "Name"
    value = "${var.cluster_name}-bastion-eip"
  }

  tags {
    key   = "Cluster"
    value = var.cluster_name
  }

  tags {
    key   = "Environment"
    value = var.environment
  }
}

resource "outscale_public_ip_link" "bastion" {
  vm_id        = outscale_vm.bastion.vm_id
  public_ip_id = outscale_public_ip.bastion.public_ip_id
}

# Control Plane Nodes
resource "outscale_vm" "control_plane" {
  count = var.control_plane_count

  image_id           = local.talos_image_id
  vm_type            = var.control_plane_vm_type
  keypair_name       = outscale_keypair.main.keypair_name
  security_group_ids = [outscale_security_group.control_plane.security_group_id]

  # Distribution multi-AZ
  subnet_id = local.kubernetes_subnets[count.index % length(local.kubernetes_subnets)]

  block_device_mappings {
    device_name = "/dev/sda1"
    bsu {
      volume_size           = var.control_plane_disk_size
      volume_type           = "gp2"
      delete_on_vm_deletion = true
    }
  }

  # IPs privées statiques
  private_ips = [
    cidrhost(local.kubernetes_subnets[count.index % length(local.kubernetes_subnets)] == outscale_subnet.kubernetes_az_a.subnet_id ? var.subnet_k8s_az_a_cidr :
      local.kubernetes_subnets[count.index % length(local.kubernetes_subnets)] == outscale_subnet.kubernetes_az_b[0].subnet_id ? var.subnet_k8s_az_b_cidr :
    var.subnet_k8s_az_c_cidr, 10 + count.index)
  ]

  tags {
    key   = "Name"
    value = "${var.cluster_name}-cp-${count.index + 1}"
  }

  tags {
    key   = "Cluster"
    value = var.cluster_name
  }

  tags {
    key   = "Environment"
    value = var.environment
  }

  tags {
    key   = "Role"
    value = "ControlPlane"
  }

  tags {
    key   = "Index"
    value = tostring(count.index + 1)
  }

  depends_on = [
    outscale_nat_service.kubernetes,
    outscale_route.kubernetes_nat
  ]
}

# Worker Nodes
resource "outscale_vm" "workers" {
  count = var.worker_count

  image_id           = local.talos_image_id
  vm_type            = var.worker_vm_type
  keypair_name       = outscale_keypair.main.keypair_name
  security_group_ids = [outscale_security_group.workers.security_group_id]

  # Distribution multi-AZ
  subnet_id = local.kubernetes_subnets[count.index % length(local.kubernetes_subnets)]

  block_device_mappings {
    device_name = "/dev/sda1"
    bsu {
      volume_size           = var.worker_disk_size
      volume_type           = "gp2"
      delete_on_vm_deletion = true
    }
  }

  # IPs privées statiques
  private_ips = [
    cidrhost(local.kubernetes_subnets[count.index % length(local.kubernetes_subnets)] == outscale_subnet.kubernetes_az_a.subnet_id ? var.subnet_k8s_az_a_cidr :
      local.kubernetes_subnets[count.index % length(local.kubernetes_subnets)] == outscale_subnet.kubernetes_az_b[0].subnet_id ? var.subnet_k8s_az_b_cidr :
    var.subnet_k8s_az_c_cidr, 20 + count.index)
  ]

  tags {
    key   = "Name"
    value = "${var.cluster_name}-worker-${count.index + 1}"
  }

  tags {
    key   = "Cluster"
    value = var.cluster_name
  }

  tags {
    key   = "Environment"
    value = var.environment
  }

  tags {
    key   = "Role"
    value = "Worker"
  }

  tags {
    key   = "Index"
    value = tostring(count.index + 1)
  }

  depends_on = [
    outscale_nat_service.kubernetes,
    outscale_route.kubernetes_nat
  ]
}
