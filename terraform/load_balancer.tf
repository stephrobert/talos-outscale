# Load Balancer (Interne) pour l'API Kubernetes
resource "outscale_load_balancer" "kubernetes" {
  load_balancer_name = "${var.cluster_name}-k8s-lb"
  load_balancer_type = var.lb_type

  # Un seul subnet requis pour le LB (il peut distribuer vers tous les subnets du VPC)
  subnets = [outscale_subnet.kubernetes_az_a.subnet_id]

  security_groups = [outscale_security_group.load_balancer.security_group_id]

  # Listener pour l'API Kubernetes
  listeners {
    backend_port           = 6443
    backend_protocol       = "TCP"
    load_balancer_port     = 6443
    load_balancer_protocol = "TCP"
  }

  # Listener pour l'API Talos
  listeners {
    backend_port           = 50000
    backend_protocol       = "TCP"
    load_balancer_port     = 50000
    load_balancer_protocol = "TCP"
  }

  tags {
    key   = "Name"
    value = "${var.cluster_name}-k8s-lb"
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
    value = "KubernetesAPI"
  }
}

# Configuration du Health Check
resource "outscale_load_balancer_attributes" "kubernetes" {
  load_balancer_name = outscale_load_balancer.kubernetes.load_balancer_name

  health_check {
    check_interval      = 30
    healthy_threshold   = 10
    port                = 6443
    protocol            = "TCP"
    timeout             = 5
    unhealthy_threshold = 5
  }
}

# Enregistrement des control planes dans le LB (sera fait après création des VMs)
resource "outscale_load_balancer_vms" "control_plane" {
  load_balancer_name = outscale_load_balancer.kubernetes.load_balancer_name
  backend_vm_ids     = outscale_vm.control_plane[*].vm_id

  depends_on = [outscale_vm.control_plane]
}
