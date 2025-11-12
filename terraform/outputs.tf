# ============================================================================
# OUTPUTS ESSENTIELS
# ============================================================================

# Connexion
output "bastion_ssh" {
  description = "Commande SSH pour se connecter au bastion"
  value       = "ssh outscale@${outscale_public_ip.bastion.public_ip}"
}

# Endpoint API Kubernetes
output "kubernetes_api" {
  description = "Endpoint de l'API Kubernetes"
  value       = "https://${outscale_load_balancer.kubernetes.dns_name}:6443"
}

# IPs des nœuds
output "control_plane_ips" {
  description = "IPs privées des control planes"
  value       = [for vm in outscale_vm.control_plane : vm.private_ip]
}

output "worker_ips" {
  description = "IPs privées des workers"
  value       = [for vm in outscale_vm.workers : vm.private_ip]
}

