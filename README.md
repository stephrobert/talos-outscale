# Talos Kubernetes sur Outscale

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Talos](https://img.shields.io/badge/Talos-v1.11.3-blue.svg)](https://www.talos.dev/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.34-blue.svg)](https://kubernetes.io/)

Déploiement automatisé d'un cluster Kubernetes hautement disponible avec **Talos Linux** sur le cloud **Outscale**.

Ce projet construis une infrastructure complète pour exécuter Kubernetes sur Outscale avec :

- **Talos Linux** : OS immuable et API-driven pour Kubernetes
- **Terraform** : Infrastructure as Code pour le provisioning
- **Packer** : Automatisation de la création d'images OMI personnalisées (standard et GPU)
- **Cilium** : CNI moderne basé sur eBPF avec kube-proxy replacement
- **Support GPU** : Workers GPU avec drivers NVIDIA pour workloads d'IA/ML
- **CSI Driver** : Stockage persistant avec volumes BSU Outscale
- **Cloud Controller Manager** : Intégration native avec Load Balancers Outscale

## 📋 Table des matières

* [Talos Kubernetes sur Outscale](#talos-kubernetes-sur-outscale)
  * [📋 Table des matières](#-table-des-matières)
  * [🏗 Architecture](#-architecture)
    * [Topologie réseau](#topologie-réseau)
    * [Composants](#composants)
  * [🔧 Prérequis](#-prérequis)
    * [Outils requis](#outils-requis)
    * [Sur votre poste de travail](#sur-votre-poste-de-travail)
    * [Sur le bastion](#sur-le-bastion)
    * [Versions testées](#versions-testées)
  * [🚀 Démarrage rapide](#-démarrage-rapide)
    * [1. Configuration des credentials](#1-configuration-des-credentials)
    * [2. Création des OMI Talos](#2-création-des-omi-talos)
      * [Image Talos Standard](#image-talos-standard)
      * [Image Talos GPU (optionnel)](#image-talos-gpu-optionnel)
    * [3. Déploiement de l'infrastructure](#3-déploiement-de-linfrastructure)
    * [4. Déploiement du cluster Kubernetes](#4-déploiement-du-cluster-kubernetes)
  * [📁 Structure du projet](#-structure-du-projet)
  * [📚 Documentation](#-documentation)
    * [Fonctionnalités principales](#fonctionnalités-principales)
      * [Support GPU NVIDIA](#support-gpu-nvidia)
      * [CSI Driver Outscale](#csi-driver-outscale)
      * [Cloud Controller Manager](#cloud-controller-manager)
  * [🤝 Contribution](#-contribution)
    * [Guidelines](#guidelines)
  * [📝 Licence](#-licence)
  * [👤 Auteur](#-auteur)

## 🏗 Architecture

### Topologie réseau

L'infrastructure repose sur une architecture multi-AZ hautement disponible :

```
┌──────────────────────────────────────────────────────────────────────────────────────┐
│                         Outscale Cloud (eu-west-2)                                   │
├──────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  ┌────────── Net Bastion (10.100.0.0/16) ──────────┐                                 │
│  │                                                 │                                 │
│  │  Bastion (10.100.1.10)                          │                                 │
│  │  ├─ SSH Access (Port 22)                        │                                 │
│  │  ├─ kubectl, talosctl, helm                     │                                 │
│  │  └─ VPC Peering ────────────────────────────────┼─────────┐                       │
│  └─────────────────────────────────────────────────┘         │                       │
│                                                              ▼                       │
│  ┌────────────────── Net Cluster Kubernetes (10.0.0.0/16) ────────────────────────┐  │
│  │                                                                                │  │
│  │  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐              │  │
│  │  │  AZ-A (.1.0/24)  │  │  AZ-B (.2.0/24)  │  │  AZ-C (.3.0/24)  │              │  │
│  │  ├──────────────────┤  ├──────────────────┤  ├──────────────────┤              │  │
│  │  │ CP-1: .1.10      │  │ CP-2: .2.11      │  │ CP-3: .3.12      │              │  │
│  │  │ Worker-1: .1.20  │  │ Worker-2: .2.21  │  │ Worker-3: .3.22  │              │  │
│  │  │ GPU-1: .1.30     │  │                  │  │                  │              │  │
│  │  └──────────────────┘  └──────────────────┘  └──────────────────┘              │  │
│  │                                                                                │  │
│  │  ┌─────────── NAT Subnet (.254.0/24) ──────────┐                               │  │
│  │  │  NAT Gateway (Public IP)                    │  → Internet                   │  │
│  │  └─────────────────────────────────────────────┘                               │  │
│  │                                                                                │  │
│  │  ┌───────── Load Balancer (Internal) ──────────┐                               │  │
│  │  │  Kubernetes API (Port 6443)                 │                               │  │
│  │  │  ├─> 10.0.1.10:6443 (CP-1)                  │                               │  │
│  │  │  ├─> 10.0.2.11:6443 (CP-2)                  │                               │  │
│  │  │  └─> 10.0.3.12:6443 (CP-3)                  │                               │  │
│  │  └─────────────────────────────────────────────┘                               │  │
│  │                                                                                │  │
│  └────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                      │
└──────────────────────────────────────────────────────────────────────────────────────┘
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

**Workers GPU (optionnels)**

- Distribution : Zones de disponibilité configurables
- Type : `tinav6.c8r16p1` ou supérieur (avec line GPU)
- Image : OMI Talos personnalisée avec drivers NVIDIA
- Extensions : nvidia-open-gpu-kernel-modules, nvidia-container-toolkit, nvidia-fabricmanager
- Drivers : NVIDIA 570.x (production)
- Support : GPU simple, multi-GPU, et systèmes HGX avec NVLink
- Rôles : Workloads IA/ML, calcul scientifique, training de modèles

**Stockage**

- Type : BSU volumes (gp2, io1, standard)
- Taille : Configurable par nœud
- Persistence : DeleteOnVmDeletion configurable

## 🔧 Prérequis

### Outils requis

Sur votre poste de travail et le bastion :

### Sur votre poste de travail

```bash
# Terraform (>= 1.0)
terraform version

# Packer (>= 1.9)
packer version

# osc-cli (CLI Outscale)
osc-cli --version
```

### Sur le bastion

```bash
# talosctl (même version que les images Talos)
talosctl version

# kubectl
kubectl version --client

# helm
helm version
```

### Versions testées

| Composant | Version |
|-----------|---------|
| Talos Linux | v1.11.5 |
| Kubernetes | v1.34.1 |
| Cilium | v1.18.4 |
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

### 2. Création des OMI Talos

Le projet supporte deux types d'images :

#### Image Talos Standard

Pour les nœuds sans GPU (control planes et workers CPU) :

```bash
cd packer

# Copier et éditer les variables
cp variables.auto.pkrvars.hcl.example variables.auto.pkrvars.hcl
vim variables.auto.pkrvars.hcl

# Initialiser Packer
packer init talos-outscale.pkr.hcl

# Valider la configuration
packer validate talos-outscale.pkr.hcl

# Build de l'OMI standard
packer build talos-outscale.pkr.hcl
```

#### Image Talos GPU (optionnel)

Pour les workers GPU avec drivers NVIDIA intégrés :

```bash
cd packer

# Initialiser si pas encore fait
packer init talos-gpu-outscale.pkr.hcl

# Valider la configuration GPU
packer validate talos-gpu-outscale.pkr.hcl

# Build de l'OMI GPU (type universal recommandé)
packer build talos-gpu-outscale.pkr.hcl
```

**Types d'images GPU disponibles :**

- **universal** (par défaut) : Inclut `nvidia-fabricmanager` pour support NVLink/HGX (H100, A100)

Les images créées auront des noms comme :

- Standard : `Talos-v1.11.5-20251126-093750`
- GPU : `Talos-GPU-universal-v1.11.5-20251126-100029`

### 3. Déploiement de l'infrastructure

```bash
cd terraform

# Copier le fichier d'exemple de variables
cp terraform.tfvars.example terraform.tfvars

# Éditer avec vos paramètres
# - Mettre l'OMI ID standard créée précédemment
# - Configurer le nombre de workers GPU (gpu_worker_count)

vim terraform.tfvars

# Initialiser Terraform
terraform init

# Planifier les changements
terraform plan

# Appliquer
terraform apply
```

**Configuration GPU dans Terraform :**

Variables disponibles pour les workers GPU :

- `gpu_worker_count` : Nombre de workers GPU (défaut: 0)
- `gpu_worker_vm_type` : Type de VM avec GPU (ex: `tinav6.c8r16p1`)
- `gpu_worker_disk_size` : Taille du disque en GB (défaut: 200)
- `gpu_worker_availability_zones` : Liste des AZ pour GPU (ex: `["a"]`)
- `talos_gpu_image_id` : ID de l'OMI GPU créée avec Packer

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
├── docs/
│   └── PROCEDURE-IMAGE-TALOS-GPU.md  # Guide détaillé création images GPU
├── .envrc.sample                  # Template de credentials
├── cilium-patch.yaml              # Patch Talos pour désactiver kube-proxy
├── packer/
│   ├── talos-outscale.pkr.hcl        # Configuration Packer image standard
│   ├── talos-gpu-outscale.pkr.hcl    # Configuration Packer image GPU
│   ├── variables.auto.pkrvars.hcl.example  # Variables Packer
│   ├── manifest.json                 # Manifest build image standard
│   ├── manifest-gpu-universal.json   # Manifest build image GPU
│   └── provision/
│       ├── playbook.yaml          # Playbook Ansible image standard
│       ├── playbook-gpu.yaml      # Playbook Ansible image GPU
│       └── schematic.yaml         # Schematic Talos (extensions)
├── terraform/
│   ├── main.tf                    # Configuration Terraform principale
│   ├── variables.tf               # Variables (inclut GPU)
│   ├── outputs.tf                 # Outputs (inclut GPU workers)
│   ├── network.tf                 # Configuration réseau
│   ├── compute.tf                 # VMs Talos (CP, workers, GPU workers)
│   ├── security_groups.tf         # Security Groups
│   ├── load_balancer.tf           # Load Balancer API Kubernetes
│   ├── keypair.tf                 # Paire de clés SSH
│   ├── terraform.tfvars.example   # Exemple de variables
│   ├── deploy-cluster.sh          # Script automatisé déploiement complet
│   ├── generate-talos-config.sh   # Script génération configs Talos
│   └── talos-patches/
│       └── gpu-worker-patch.yaml  # Patch Talos pour workers GPU
├── kubernetes/
│   ├── storageclass-outscale.yaml    # StorageClass CSI Outscale
│   ├── test-csi-pvc.yaml             # Tests PVC
│   ├── test-gpu-pod.yaml             # Tests GPU
│   ├── install-gpu-operator.sh       # Installation GPU Operator
│   └── setup-gpu-node.sh             # Configuration nœud GPU
└── _out/                          # Outputs générés
    ├── talosconfig
    ├── kubeconfig
    ├── controlplane.yaml
    ├── worker.yaml
    ├── gpu-worker.yaml            # Config worker GPU
    ├── gpu-operator-values-clean.yaml  # Values GPU Operator
    └── GPU-OPERATOR-INSTALL-GUIDE.md   # Guide GPU Operator
```

## 📚 Documentation

Documentation disponible :

- **Guide complet de déploiement** : [Déploiement Talos sur Outscale](https://blog.stephane-robert.info/docs/cloud/outscale/kubernetes-talos/)

Ressources externes :

- **Talos officiel** : <https://www.talos.dev/>
- **Cilium** : <https://docs.cilium.io/>
- **Terraform Outscale** : <https://registry.terraform.io/providers/outscale/outscale/>

### Fonctionnalités principales

#### Support GPU NVIDIA

Le projet supporte le déploiement de workers GPU avec :

- **Images personnalisées** : OMI Talos avec drivers NVIDIA pré-installés
- **Extensions Talos** : nvidia-open-gpu-kernel-modules, nvidia-container-toolkit, nvidia-fabricmanager
- **Drivers** : NVIDIA 570.x (production)
- **Configurations** : GPU simple, multi-GPU, et systèmes HGX avec NVLink
- **GPU Operator** : Installation et gestion automatisées des composants GPU

#### CSI Driver Outscale

Support du stockage persistant avec volumes BSU :

- **StorageClass** : gp2, io1, standard
- **Dynamic provisioning** : Création automatique de volumes
- **Volume expansion** : Redimensionnement à chaud
- **Snapshots** : Sauvegarde et restauration

#### Cloud Controller Manager

Intégration native avec les services Outscale :

- **Load Balancers** : Création automatique de LB pour les Services Kubernetes
- **Node management** : Synchronisation des métadonnées VM/Node
- **Zone awareness** : Distribution multi-AZ intelligente

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

- Blog: <https://blog.stephane-robert.info>
- GitHub: [@stephrobert](https://github.com/stephrobert)
- LinkedIn: [Stéphane Robert](https://www.linkedin.com/in/stephanerobert1/)

---

⭐ **Si ce projet vous est utile, n'hésitez pas à lui mettre une star !**
