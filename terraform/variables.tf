# Variables générales
variable "access_key_id" {
  description = "Outscale Access Key ID"
  type        = string
  sensitive   = true
}

variable "secret_key_id" {
  description = "Outscale Secret Key ID"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "Région Outscale"
  type        = string
  default     = "eu-west-2"
}

variable "cluster_name" {
  description = "Nom du cluster Kubernetes"
  type        = string
  default     = "talos-prod"
}

variable "environment" {
  description = "Environnement (production, staging, dev)"
  type        = string
  default     = "production"
}

# Network Configuration
variable "vpc_k8s_cidr" {
  description = "CIDR pour le VPC Kubernetes"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_bastion_cidr" {
  description = "CIDR pour le VPC Bastion"
  type        = string
  default     = "10.100.0.0/16"
}

variable "subnet_k8s_az_a_cidr" {
  description = "CIDR pour le subnet Kubernetes AZ-A"
  type        = string
  default     = "10.0.1.0/24"
}

variable "subnet_k8s_az_b_cidr" {
  description = "CIDR pour le subnet Kubernetes AZ-B"
  type        = string
  default     = "10.0.2.0/24"
}

variable "subnet_k8s_az_c_cidr" {
  description = "CIDR pour le subnet Kubernetes AZ-C"
  type        = string
  default     = "10.0.3.0/24"
}

variable "subnet_k8s_nat_cidr" {
  description = "CIDR pour le subnet NAT Gateway"
  type        = string
  default     = "10.0.254.0/24"
}

variable "subnet_bastion_cidr" {
  description = "CIDR pour le subnet Bastion"
  type        = string
  default     = "10.100.1.0/24"
}

# Talos Configuration
variable "talos_version" {
  description = "Version de Talos"
  type        = string
  default     = "v1.10.6"
}

variable "talos_image_id" {
  description = "ID de l'OMI Talos (laisser vide pour auto-détection)"
  type        = string
  default     = ""
}

# Control Plane Configuration
variable "control_plane_count" {
  description = "Nombre de control plane nodes"
  type        = number
  default     = 3

  validation {
    condition     = var.control_plane_count >= 1 && var.control_plane_count <= 5
    error_message = "Le nombre de control planes doit être entre 1 et 5."
  }
}

variable "control_plane_vm_type" {
  description = "Type de VM pour control planes"
  type        = string
  default     = "tinav5.c4r8p1" # 4 vCPU, 8GB RAM
}

variable "control_plane_disk_size" {
  description = "Taille du disque pour control planes (GB)"
  type        = number
  default     = 50
}

# Worker Configuration
variable "worker_count" {
  description = "Nombre de worker nodes"
  type        = number
  default     = 3

  validation {
    condition     = var.worker_count >= 0 && var.worker_count <= 20
    error_message = "Le nombre de workers doit être entre 0 et 20."
  }
}

variable "worker_vm_type" {
  description = "Type de VM pour workers"
  type        = string
  default     = "tinav5.c4r16p1" # 4 vCPU, 16GB RAM
}

variable "worker_disk_size" {
  description = "Taille du disque pour workers (GB)"
  type        = number
  default     = 100
}

# Bastion Configuration
variable "bastion_vm_type" {
  description = "Type de VM pour le bastion"
  type        = string
  default     = "tinav5.c1r2p1" # 1 vCPU, 2GB RAM
}

variable "bastion_image_id" {
  description = "ID de l'OMI pour le bastion (Ubuntu 22.04 recommandé)"
  type        = string
  default     = "" # Sera auto-détecté
}

variable "bastion_allowed_ssh_cidr" {
  description = "CIDR autorisé pour SSH vers le bastion (par défaut votre IP)"
  type        = string
  default     = "" # Sera auto-détecté
}

variable "ssh_public_key_path" {
  description = "Chemin vers la clé publique SSH pour l'accès aux VMs"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

# Load Balancer Configuration
variable "lb_type" {
  description = "Type de Load Balancer (internet-facing ou internal)"
  type        = string
  default     = "internal"

  validation {
    condition     = contains(["internet-facing", "internal"], var.lb_type)
    error_message = "Le type de LB doit être 'internet-facing' ou 'internal'."
  }
}

# Security
variable "enable_talos_api_from_internet" {
  description = "Autoriser l'accès à l'API Talos depuis internet (via bastion uniquement recommandé)"
  type        = bool
  default     = false
}

variable "enable_k8s_api_from_internet" {
  description = "Autoriser l'accès à l'API Kubernetes depuis internet (via bastion uniquement recommandé)"
  type        = bool
  default     = false
}

# High Availability
variable "enable_multi_az" {
  description = "Déployer sur plusieurs AZs (recommandé pour la production)"
  type        = bool
  default     = true
}

variable "availability_zones" {
  description = "Zones de disponibilité à utiliser"
  type        = list(string)
  default     = ["a", "b", "c"]
}

# Monitoring & Logging
variable "enable_monitoring" {
  description = "Activer le monitoring avancé"
  type        = bool
  default     = true
}

variable "enable_detailed_monitoring" {
  description = "Activer le monitoring détaillé (coût supplémentaire)"
  type        = bool
  default     = false
}

# Backup
variable "enable_snapshots" {
  description = "Créer des snapshots automatiques"
  type        = bool
  default     = true
}

variable "snapshot_retention_days" {
  description = "Nombre de jours de rétention des snapshots"
  type        = number
  default     = 7
}

# Tags additionnels
variable "additional_tags" {
  description = "Tags additionnels à ajouter à toutes les ressources"
  type        = map(string)
  default     = {}
}
