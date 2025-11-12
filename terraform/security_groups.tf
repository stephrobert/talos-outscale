# ============================================================================
# Locals pour définir les règles de sécurité de manière centralisée
# ============================================================================

locals {
  # Règles bastion
  bastion_rules = {
    ssh = {
      from_port = 22
      to_port   = 22
      protocol  = "tcp"
      cidr      = coalesce(var.bastion_allowed_ssh_cidr, local.my_ip_cidr)
    }
  }

  # Règles control-plane depuis IP/CIDR
  control_plane_cidr_rules = {
    talos_from_bastion = {
      from_port = 50000
      to_port   = 50000
      protocol  = "tcp"
      cidr      = var.vpc_bastion_cidr
    }
  }

  # Règles control-plane depuis security groups
  control_plane_sg_rules = {
    k8s_api_from_lb = {
      from_port     = 6443
      to_port       = 6443
      protocol      = "tcp"
      source_sg     = "load_balancer"
    }
    talos_from_lb = {
      from_port     = 50000
      to_port       = 50000
      protocol      = "tcp"
      source_sg     = "load_balancer"
    }
    etcd_from_cp = {
      from_port     = 2379
      to_port       = 2380
      protocol      = "tcp"
      source_sg     = "control_plane"
    }
    talos_from_cp = {
      from_port     = 50000
      to_port       = 50000
      protocol      = "tcp"
      source_sg     = "control_plane"
    }
    k8s_api_from_cp = {
      from_port     = 6443
      to_port       = 6443
      protocol      = "tcp"
      source_sg     = "control_plane"
    }
    kubelet_from_cp = {
      from_port     = 10250
      to_port       = 10250
      protocol      = "tcp"
      source_sg     = "control_plane"
    }
    cilium_health_from_cp = {
      from_port     = 4240
      to_port       = 4240
      protocol      = "tcp"
      source_sg     = "control_plane"
    }
    cilium_hubble_from_cp = {
      from_port     = 4244
      to_port       = 4245
      protocol      = "tcp"
      source_sg     = "control_plane"
    }
    k8s_api_from_workers = {
      from_port     = 6443
      to_port       = 6443
      protocol      = "tcp"
      source_sg     = "workers"
    }
    kubelet_from_workers = {
      from_port     = 10250
      to_port       = 10250
      protocol      = "tcp"
      source_sg     = "workers"
    }
    cilium_health_from_workers = {
      from_port     = 4240
      to_port       = 4240
      protocol      = "tcp"
      source_sg     = "workers"
    }
    cilium_hubble_from_workers = {
      from_port     = 4244
      to_port       = 4245
      protocol      = "tcp"
      source_sg     = "workers"
    }
  }

  # Règles workers depuis IP/CIDR
  workers_cidr_rules = {
    talos_from_bastion = {
      from_port = 50000
      to_port   = 50000
      protocol  = "tcp"
      cidr      = var.vpc_bastion_cidr
    }
    nodeport_from_bastion = {
      from_port = 30000
      to_port   = 32767
      protocol  = "tcp"
      cidr      = var.vpc_bastion_cidr
    }
  }

  # Règles workers depuis security groups
  workers_sg_rules = {
    kubelet_from_cp = {
      from_port = 10250
      to_port   = 10250
      protocol  = "tcp"
      source_sg = "control_plane"
    }
    cilium_health_from_cp = {
      from_port = 4240
      to_port   = 4240
      protocol  = "tcp"
      source_sg = "control_plane"
    }
    cilium_hubble_from_cp = {
      from_port = 4244
      to_port   = 4245
      protocol  = "tcp"
      source_sg = "control_plane"
    }
    vxlan_from_cp = {
      from_port = 8472
      to_port   = 8472
      protocol  = "udp"
      source_sg = "control_plane"
    }
    kubelet_internal = {
      from_port = 10250
      to_port   = 10250
      protocol  = "tcp"
      source_sg = "workers"
    }
    cilium_health_internal = {
      from_port = 4240
      to_port   = 4240
      protocol  = "tcp"
      source_sg = "workers"
    }
    cilium_hubble_internal = {
      from_port = 4244
      to_port   = 4245
      protocol  = "tcp"
      source_sg = "workers"
    }
    vxlan_internal = {
      from_port = 8472
      to_port   = 8472
      protocol  = "udp"
      source_sg = "workers"
    }
  }

  # Règles load balancer depuis IP/CIDR
  lb_cidr_rules = {
    k8s_api_from_bastion = {
      from_port = 6443
      to_port   = 6443
      protocol  = "tcp"
      cidr      = var.vpc_bastion_cidr
    }
    talos_from_bastion = {
      from_port = 50000
      to_port   = 50000
      protocol  = "tcp"
      cidr      = var.vpc_bastion_cidr
    }
  }

  # Règles load balancer depuis security groups
  lb_sg_rules = {
    k8s_api_from_workers = {
      from_port = 6443
      to_port   = 6443
      protocol  = "tcp"
      source_sg = "workers"
    }
    k8s_api_from_cp = {
      from_port = 6443
      to_port   = 6443
      protocol  = "tcp"
      source_sg = "control_plane"
    }
  }

  # Mapping des noms de SG vers les ressources
  sg_map = {
    control_plane = outscale_security_group.control_plane.security_group_name
    workers       = outscale_security_group.workers.security_group_name
    load_balancer = outscale_security_group.load_balancer.security_group_name
  }
}

# ============================================================================
# Security Groups
# ============================================================================

# Security Group Bastion
resource "outscale_security_group" "bastion" {
  description         = "${var.cluster_name} Bastion Security Group"
  security_group_name = "${var.cluster_name}-bastion-sg"
  net_id              = outscale_net.bastion.net_id

  tags {
    key   = "Name"
    value = "${var.cluster_name}-bastion-sg"
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

# Règles Bastion
resource "outscale_security_group_rule" "bastion" {
  for_each = local.bastion_rules

  flow              = "Inbound"
  security_group_id = outscale_security_group.bastion.security_group_id
  from_port_range   = each.value.from_port
  to_port_range     = each.value.to_port
  ip_protocol       = each.value.protocol
  ip_range          = each.value.cidr
}


# Security Group Control Plane
resource "outscale_security_group" "control_plane" {
  description         = "${var.cluster_name} Control Plane Security Group"
  security_group_name = "${var.cluster_name}-cp-sg"
  net_id              = outscale_net.kubernetes.net_id

  tags {
    key   = "Name"
    value = "${var.cluster_name}-cp-sg"
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
}

# Règles Control Plane depuis CIDR
resource "outscale_security_group_rule" "control_plane_cidr" {
  for_each = local.control_plane_cidr_rules

  flow              = "Inbound"
  security_group_id = outscale_security_group.control_plane.security_group_id
  from_port_range   = each.value.from_port
  to_port_range     = each.value.to_port
  ip_protocol       = each.value.protocol
  ip_range          = each.value.cidr
}

# Règles Control Plane depuis Security Groups
resource "outscale_security_group_rule" "control_plane_sg" {
  for_each = local.control_plane_sg_rules

  flow              = "Inbound"
  security_group_id = outscale_security_group.control_plane.security_group_id

  rules {
    from_port_range = each.value.from_port
    to_port_range   = each.value.to_port
    ip_protocol     = each.value.protocol
    security_groups_members {
      security_group_name = local.sg_map[each.value.source_sg]
    }
  }
}

# Security Group Workers
resource "outscale_security_group" "workers" {
  description         = "${var.cluster_name} Worker Nodes Security Group"
  security_group_name = "${var.cluster_name}-worker-sg"
  net_id              = outscale_net.kubernetes.net_id

  tags {
    key   = "Name"
    value = "${var.cluster_name}-worker-sg"
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
}

# Règles Workers depuis CIDR
resource "outscale_security_group_rule" "workers_cidr" {
  for_each = local.workers_cidr_rules

  flow              = "Inbound"
  security_group_id = outscale_security_group.workers.security_group_id
  from_port_range   = each.value.from_port
  to_port_range     = each.value.to_port
  ip_protocol       = each.value.protocol
  ip_range          = each.value.cidr
}

# Règles Workers depuis Security Groups
resource "outscale_security_group_rule" "workers_sg" {
  for_each = local.workers_sg_rules

  flow              = "Inbound"
  security_group_id = outscale_security_group.workers.security_group_id

  rules {
    from_port_range = each.value.from_port
    to_port_range   = each.value.to_port
    ip_protocol     = each.value.protocol
    security_groups_members {
      security_group_name = local.sg_map[each.value.source_sg]
    }
  }
}

# Security Group Load Balancer
resource "outscale_security_group" "load_balancer" {
  description         = "${var.cluster_name} Load Balancer Security Group"
  security_group_name = "${var.cluster_name}-lb-sg"
  net_id              = outscale_net.kubernetes.net_id

  tags {
    key   = "Name"
    value = "${var.cluster_name}-lb-sg"
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
    value = "LoadBalancer"
  }
}

# Règles Load Balancer depuis CIDR
resource "outscale_security_group_rule" "lb_cidr" {
  for_each = local.lb_cidr_rules

  flow              = "Inbound"
  security_group_id = outscale_security_group.load_balancer.security_group_id
  from_port_range   = each.value.from_port
  to_port_range     = each.value.to_port
  ip_protocol       = each.value.protocol
  ip_range          = each.value.cidr
}

# Règles Load Balancer depuis Security Groups
resource "outscale_security_group_rule" "lb_sg" {
  for_each = local.lb_sg_rules

  flow              = "Inbound"
  security_group_id = outscale_security_group.load_balancer.security_group_id

  rules {
    from_port_range = each.value.from_port
    to_port_range   = each.value.to_port
    ip_protocol     = each.value.protocol
    security_groups_members {
      security_group_name = local.sg_map[each.value.source_sg]
    }
  }
}
