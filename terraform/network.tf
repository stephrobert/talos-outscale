# VPC Kubernetes
resource "outscale_net" "kubernetes" {
  ip_range = var.vpc_k8s_cidr

  tags {
    key   = "Name"
    value = "${var.cluster_name}-k8s-vpc"
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

# VPC Bastion
resource "outscale_net" "bastion" {
  ip_range = var.vpc_bastion_cidr

  tags {
    key   = "Name"
    value = "${var.cluster_name}-bastion-vpc"
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

# Subnets Kubernetes (Multi-AZ)
resource "outscale_subnet" "kubernetes_az_a" {
  net_id         = outscale_net.kubernetes.net_id
  ip_range       = var.subnet_k8s_az_a_cidr
  subregion_name = "${var.region}a"

  tags {
    key   = "Name"
    value = "${var.cluster_name}-k8s-az-a"
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
    key   = "AZ"
    value = "a"
  }
}

resource "outscale_subnet" "kubernetes_az_b" {
  count = var.enable_multi_az ? 1 : 0

  net_id         = outscale_net.kubernetes.net_id
  ip_range       = var.subnet_k8s_az_b_cidr
  subregion_name = "${var.region}b"

  tags {
    key   = "Name"
    value = "${var.cluster_name}-k8s-az-b"
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
    key   = "AZ"
    value = "b"
  }
}

resource "outscale_subnet" "kubernetes_az_c" {
  count = var.enable_multi_az ? 1 : 0

  net_id         = outscale_net.kubernetes.net_id
  ip_range       = var.subnet_k8s_az_c_cidr
  subregion_name = "${var.region}c"

  tags {
    key   = "Name"
    value = "${var.cluster_name}-k8s-az-c"
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
    key   = "AZ"
    value = "c"
  }
}

# Subnet NAT (Public)
resource "outscale_subnet" "nat" {
  net_id         = outscale_net.kubernetes.net_id
  ip_range       = var.subnet_k8s_nat_cidr
  subregion_name = "${var.region}a"

  tags {
    key   = "Name"
    value = "${var.cluster_name}-nat-subnet"
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
    key   = "Type"
    value = "Public"
  }
}

# Subnet Bastion
resource "outscale_subnet" "bastion" {
  net_id         = outscale_net.bastion.net_id
  ip_range       = var.subnet_bastion_cidr
  subregion_name = "${var.region}a"

  tags {
    key   = "Name"
    value = "${var.cluster_name}-bastion-subnet"
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
    key   = "Type"
    value = "Public"
  }
}

# Internet Gateways
resource "outscale_internet_service" "kubernetes" {
  tags {
    key   = "Name"
    value = "${var.cluster_name}-k8s-igw"
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

resource "outscale_internet_service_link" "kubernetes" {
  internet_service_id = outscale_internet_service.kubernetes.internet_service_id
  net_id              = outscale_net.kubernetes.net_id
}

resource "outscale_internet_service" "bastion" {
  tags {
    key   = "Name"
    value = "${var.cluster_name}-bastion-igw"
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

resource "outscale_internet_service_link" "bastion" {
  internet_service_id = outscale_internet_service.bastion.internet_service_id
  net_id              = outscale_net.bastion.net_id
}

# NAT Gateway pour accès internet sortant des nodes K8s
resource "outscale_public_ip" "nat" {
  tags {
    key   = "Name"
    value = "${var.cluster_name}-nat-eip"
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

resource "outscale_nat_service" "kubernetes" {
  subnet_id    = outscale_subnet.nat.subnet_id
  public_ip_id = outscale_public_ip.nat.public_ip_id

  tags {
    key   = "Name"
    value = "${var.cluster_name}-nat-gateway"
  }

  tags {
    key   = "Cluster"
    value = var.cluster_name
  }

  tags {
    key   = "Environment"
    value = var.environment
  }

  depends_on = [outscale_route.nat_public]
}

# VPC Peering
resource "outscale_net_peering" "bastion_to_kubernetes" {
  accepter_net_id = outscale_net.kubernetes.net_id
  source_net_id   = outscale_net.bastion.net_id

  tags {
    key   = "Name"
    value = "${var.cluster_name}-vpc-peering"
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

resource "outscale_net_peering_acceptation" "bastion_to_kubernetes" {
  net_peering_id = outscale_net_peering.bastion_to_kubernetes.net_peering_id
}

# Route Tables
# Route table publique (pour NAT subnet)
resource "outscale_route_table" "nat_public" {
  net_id = outscale_net.kubernetes.net_id

  tags {
    key   = "Name"
    value = "${var.cluster_name}-nat-public-rt"
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

resource "outscale_route" "nat_public" {
  route_table_id       = outscale_route_table.nat_public.route_table_id
  destination_ip_range = "0.0.0.0/0"
  gateway_id           = outscale_internet_service.kubernetes.internet_service_id
}

resource "outscale_route_table_link" "nat" {
  route_table_id = outscale_route_table.nat_public.route_table_id
  subnet_id      = outscale_subnet.nat.subnet_id
}

# Route table privée (pour subnets K8s) via NAT Gateway
resource "outscale_route_table" "kubernetes_private" {
  net_id = outscale_net.kubernetes.net_id

  tags {
    key   = "Name"
    value = "${var.cluster_name}-k8s-private-rt"
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

resource "outscale_route" "kubernetes_nat" {
  route_table_id       = outscale_route_table.kubernetes_private.route_table_id
  destination_ip_range = "0.0.0.0/0"
  nat_service_id       = outscale_nat_service.kubernetes.nat_service_id
}

resource "outscale_route" "kubernetes_to_bastion" {
  route_table_id       = outscale_route_table.kubernetes_private.route_table_id
  destination_ip_range = var.vpc_bastion_cidr
  net_peering_id       = outscale_net_peering.bastion_to_kubernetes.net_peering_id
}

resource "outscale_route_table_link" "kubernetes_az_a" {
  route_table_id = outscale_route_table.kubernetes_private.route_table_id
  subnet_id      = outscale_subnet.kubernetes_az_a.subnet_id
}

resource "outscale_route_table_link" "kubernetes_az_b" {
  count = var.enable_multi_az ? 1 : 0

  route_table_id = outscale_route_table.kubernetes_private.route_table_id
  subnet_id      = outscale_subnet.kubernetes_az_b[0].subnet_id
}

resource "outscale_route_table_link" "kubernetes_az_c" {
  count = var.enable_multi_az ? 1 : 0

  route_table_id = outscale_route_table.kubernetes_private.route_table_id
  subnet_id      = outscale_subnet.kubernetes_az_c[0].subnet_id
}

# Route table Bastion
resource "outscale_route_table" "bastion" {
  net_id = outscale_net.bastion.net_id

  tags {
    key   = "Name"
    value = "${var.cluster_name}-bastion-rt"
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

resource "outscale_route" "bastion_internet" {
  route_table_id       = outscale_route_table.bastion.route_table_id
  destination_ip_range = "0.0.0.0/0"
  gateway_id           = outscale_internet_service.bastion.internet_service_id
}

resource "outscale_route" "bastion_to_kubernetes" {
  route_table_id       = outscale_route_table.bastion.route_table_id
  destination_ip_range = var.vpc_k8s_cidr
  net_peering_id       = outscale_net_peering.bastion_to_kubernetes.net_peering_id
}

resource "outscale_route_table_link" "bastion" {
  route_table_id = outscale_route_table.bastion.route_table_id
  subnet_id      = outscale_subnet.bastion.subnet_id
}
