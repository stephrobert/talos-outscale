# Talos Kubernetes sur Outscale

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Talos](https://img.shields.io/badge/Talos-v1.11.3-blue.svg)](https://www.talos.dev/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.34-blue.svg)](https://kubernetes.io/)

Déploiement automatisé d'un cluster Kubernetes hautement disponible avec **Talos Linux** sur le cloud **Outscale**.

Ce projet construis une infrastructure complète pour exécuter Kubernetes sur Outscale avec :

- **Talos Linux** : OS immuable et API-driven pour Kubernetes
- **Terraform** : Infrastructure as Code pour le provisioning
- **Packer** : Automatisation de la création d'images OMI personnalisées
- **Cilium** : CNI moderne basé sur eBPF avec kube-proxy replacement

## 📋 Table des matières

* [Talos Kubernetes sur Outscale](#talos-kubernetes-sur-outscale)
  * [📋 Table des matières](#-table-des-matières)
  * [🏗 Architecture](#-architecture)
    * [Topologie réseau](#topologie-réseau)
    * [Composants](#composants)
  * [🔧 Prérequis](#-prérequis)
    * [Outils requis](#outils-requis)
    * [Credentials Outscale](#credentials-outscale)
    * [Versions testées](#versions-testées)
  * [🚀 Démarrage rapide](#-démarrage-rapide)
    * [1. Configuration des credentials](#1-configuration-des-credentials)
    * [2. Création de l'image OMI Talos](#2-création-de-limage-omi-talos)
    * [3. Déploiement de l'infrastructure](#3-déploiement-de-linfrastructure)
    * [4. Déploiement du cluster Kubernetes](#4-déploiement-du-cluster-kubernetes)
  * [📁 Structure du projet](#-structure-du-projet)
  * [📚 Documentation](#-documentation)
  * [🤝 Contribution](#-contribution)
    * [Guidelines](#guidelines)
  * [📝 Licence](#-licence)
  * [👤 Auteur](#-auteur)

## 🏗 Architecture

### Topologie réseau

L'infrastructure repose sur une architecture multi-AZ hautement disponible :

```
┌──────────────────────────────────────────────────────────────────────┐
│                    Outscale Cloud (eu-west-2)                        │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │ Net Cluster Kubernetes (10.0.0.0/16)                           │  │
│  │                                                                │  │
│  │  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────┐  │  │
│  │  │ AZ-1 (10.0.1/24) │  │ AZ-2 (10.0.2/24) │  │ AZ-3 (.3/24) │  │  │
│  │  ├──────────────────┤  ├──────────────────┤  ├──────────────┤  │  │
│  │  │ CP-1: .1.10      │  │ CP-2: .2.11      │  │ CP-3: .3.12  │  │  │
│  │  │ Worker-1: .1.20  │  │ Worker-2: .2.21  │  │              │  │  │
│  │  └──────────────────┘  └──────────────────┘  └──────────────┘  │  │
│  │                                                                │  │
│  │  Load Balancer Internal                                        │  │
│  │  ├─> 10.0.1.10:6443 (talos-cp-1)                               │  │
│  │  ├─> 10.0.2.11:6443 (talos-cp-2)                               │  │
│  │  └─> 10.0.3.12:6443 (talos-cp-3)                               │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

### Composants

**Réseau**

- CNI : Cilium (eBPF, native routing mode)
- Pod CIDR : `10.244.0.0/16`
- Service CIDR : `10.96.0.0/12`
- kube-proxy : Désactivé (remplacé par Cilium)
- MTU : 9001 (jumbo frames Outscale)

**Control Plane (3 nœuds)**

- Distribution : 3 zones de disponibilité (AZ-1, AZ-2, AZ-3)
- Type : `tinav6.c4r8p2` (4 vCPU, 8 GB RAM)
- Rôles : etcd, kube-apiserver, kube-controller-manager, kube-scheduler
- HA : Quorum etcd 3 nœuds (tolère 1 panne)

**Workers (2+ nœuds)**

- Distribution : 2 zones de disponibilité minimum
- Type : Configurable selon les charges applicatives
- Rôles : Hébergement des workloads Kubernetes

**Stockage**

- Type : BSU volumes (gp2)
- Taille : Configurable par nœud
- Persistence : DeleteOnVmDeletion configurable

## 🔧 Prérequis

### Outils requis

Sur votre poste de travail ou bastion :

```bash
# Terraform (>= 1.0)
terraform version

# Packer (>= 1.9)
packer version

# talosctl (même version que Talos)
talosctl version

# kubectl
kubectl version --client

# helm (optionnel, pour Cilium)
helm version

# AWS CLI (pour Object Storage Outscale)
aws --version

# osc-cli (CLI Outscale)
osc-cli --version

# Utilitaires image
qemu-img --version
```

### Credentials Outscale

Vous aurez besoin de credentials Outscale :

- Gestion des Nets, Subnets, Routes
- Création de VMs et volumes BSU
- Création d'OMI et snapshots
- Accès à l'Object Storage (OSU)
- Gestion des Security Groups et Load Balancers

### Versions testées

| Composant | Version |
|-----------|---------|
| Talos Linux | v1.11.3 |
| Kubernetes | v1.31.1 |
| Cilium | v1.16+ |
| Terraform | v1.9+ |
| Packer | v1.11+ |

## 🚀 Démarrage rapide

### 1. Configuration des credentials

Clonez le repository et configurez vos credentials :

```bash
git clone https://github.com/stephrobert/talos-outscale.git
cd talos-outscale

# Copier le fichier d'exemple
cp .envrc.sample .envrc

# Éditer avec vos credentials
vim .envrc
```

Contenu de `.envrc` :

```bash
export OSC_ACCESS_KEY="VOTRE_ACCESS_KEY"
export OSC_SECRET_KEY="VOTRE_SECRET_KEY"
export OSC_REGION="eu-west-2"

export TF_VAR_access_key_id="$OSC_ACCESS_KEY"
export TF_VAR_secret_key_id="$OSC_SECRET_KEY"

export PACKER_LOG=1
export PACKER_LOG_PATH="./packer.log"
```

Chargez les variables :

```bash
source .envrc
# Ou avec direnv
direnv allow
```

### 2. Création de l'image OMI Talos

L'image OMI personnalisée inclut les optimisations pour Outscale.

```bash
cd packer

# Initialiser Packer
packer init .

# Valider la configuration
packer validate -var="talos_version=v1.11.3" -var="source_omi=ami-0fb6a6b2" .

# Build de l'OMI
packer build -var="talos_version=v1.11.3" -var="source_omi=ami-0fb6a6b2" .
```

L'OMI créée aura un nom comme : `Talos-Outscale-v1.11.3-20251111-081824`

### 3. Déploiement de l'infrastructure

```bash
cd terraform-production

# Copier le fichier d'exemple de variables
cp terraform.tfvars.example terraform.tfvars

# Éditer avec vos paramètres (notamment l'OMI ID créé précédemment)
vim terraform.tfvars

# Initialiser Terraform
terraform init

# Planifier les changements
terraform plan

# Appliquer
terraform apply
```

### 4. Déploiement du cluster Kubernetes

Pour le bootstrap du cluster Kubernetes et l'installation de Cilium, consultez le **guide complet de déploiement** :

📖 **[Guide de déploiement Talos sur Outscale](https://blog.stephane-robert.info/docs/cloud/outscale/kubernetes-talos/)**

Ce guide détaille :

- La génération des configurations Talos
- Le bootstrap du cluster etcd
- L'installation et la configuration de Cilium CNI
- Les tests de connectivité
- Le troubleshooting

🎉 **Votre cluster Kubernetes Talos sera opérationnel !**

## 📁 Structure du projet

```text
.
├── README.md                      # Ce fichier
├── docs.mdx                       # Documentation complète
├── .envrc.sample                  # Template de credentials
├── cilium-patch.yaml              # Patch Talos pour désactiver kube-proxy
├── packer/
│   ├── talos-outscale.pkr.hcl    # Configuration Packer
│   └── provision/
│       ├── playbook.yaml          # Playbook Ansible pour provisionner l'image
│       └── schematic.yaml         # Schematic Talos (customizations kernel)
├── terraform-production/
│   ├── main.tf                    # Configuration Terraform principale
│   ├── variables.tf               # Variables d'entrée
│   ├── outputs.tf                 # Outputs exposés
│   ├── network.tf                 # Configuration réseau (Nets, Subnets, Routes)
│   ├── compute.tf                 # VMs Talos (control-planes et workers)
│   ├── security_groups.tf         # Security Groups
│   ├── load_balancer.tf           # Load Balancer pour l'API Kubernetes
│   ├── keypair.tf                 # Paire de clés SSH
│   └── terraform.tfvars.example   # Exemple de variables
└── _out/                          # Outputs générés (talosconfig, kubeconfig)
    ├── talosconfig
    ├── kubeconfig
    ├── controlplane.yaml
    └── worker.yaml
```

## 📚 Documentation

- **Talos officiel** : https://www.talos.dev/
- **Cilium** : https://docs.cilium.io/
- **Terraform Outscale** : https://registry.terraform.io/providers/outscale/outscale/
- **Article de blog** : https://blog.stephane-robert.info/docs/cloud/outscale/kubernetes-talos/

## 🤝 Contribution

Les contributions sont les bienvenues ! N'hésitez pas à :

1. Forker le projet
2. Créer une branche feature (`git checkout -b feature/AmazingFeature`)
3. Commiter vos changements (`git commit -m 'Add some AmazingFeature'`)
4. Pousser vers la branche (`git push origin feature/AmazingFeature`)
5. Ouvrir une Pull Request

### Guidelines

- Respectez la structure du projet
- Documentez les nouveaux composants
- Testez sur une infrastructure de dev avant de proposer
- Mettez à jour le README si nécessaire

## 📝 Licence

Ce projet est distribué sous licence Apache 2.0. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

## 👤 Auteur

**Stéphane Robert**

- Blog: https://blog.stephane-robert.info
- GitHub: [@stephrobert](https://github.com/stephrobert)
- LinkedIn: [Stéphane Robert](https://www.linkedin.com/in/stephanerobert1/)

---

⭐ **Si ce projet vous est utile, n'hésitez pas à lui mettre une star !**
