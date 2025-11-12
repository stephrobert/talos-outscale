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
  * [🚀 Installation](#-installation)
    * [1. Configuration des credentials](#1-configuration-des-credentials)
    * [2. Création de l'image OMI Talos](#2-création-de-limage-omi-talos)
      * [Option A : Avec Packer (recommandé)](#option-a--avec-packer-recommandé)
    * [3. Déploiement de l'infrastructure](#3-déploiement-de-linfrastructure)
    * [4. Bootstrap du cluster Kubernetes](#4-bootstrap-du-cluster-kubernetes)
    * [5. Installation du CNI Cilium](#5-installation-du-cni-cilium)
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
┌─────────────────────────────────────────────────────────────────┐
│                    Outscale Cloud (eu-west-2)                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Net Cluster Kubernetes (10.0.0.0/16)                     │  │
│  │                                                           │  │
│  │  ┌────────────────┐  ┌────────────────┐  ┌────────────┐ │  │
│  │  │ AZ-1 (10.0.1/24)│  │ AZ-2 (10.0.2/24)│  │ AZ-3 (.3/24)│ │  │
│  │  ├────────────────┤  ├────────────────┤  ├────────────┤ │  │
│  │  │ CP-1: .1.10   │  │ CP-2: .2.11   │  │ CP-3: .3.12│ │  │
│  │  │ Worker-1: .1.20│  │ Worker-2: .2.21│  │            │ │  │
│  │  └────────────────┘  └────────────────┘  └────────────┘ │  │
│  │                                                           │  │
│  │  Load Balancer Internal                                  │  │
│  │  ├─> 10.0.1.10:6443 (talos-cp-1)                        │  │
│  │  ├─> 10.0.2.11:6443 (talos-cp-2)                        │  │
│  │  └─> 10.0.3.12:6443 (talos-cp-3)                        │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
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

## 🚀 Installation

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

#### Option A : Avec Packer (recommandé)

```bash
cd packer

# Initialiser Packer
packer init .

# Valider la configuration
packer validate -var="talos_version=v1.11.3" -var="source_omi=ami-0fb6a6b2" .

# Build de l'OMI
packer build -var="talos_version=v1.11.3" -var="source_omi=ami-0fb6a6b2" .
```

Le processus :

1. Crée une VM temporaire
2. Soumet le schematic Talos à l'Image Factory
3. Télécharge l'image personnalisée
4. Écrit l'image sur un volume BSU
5. Crée un snapshot puis une OMI
6. Nettoie les ressources temporaires

L'OMI créée aura un nom comme : `Talos-Outscale-v1.11.3-20251111-081824`

### 3. Déploiement de l'infrastructure

```bash
cd terraform-production

# Copier le fichier d'exemple de variables
cp terraform.tfvars.example terraform.tfvars

# Éditer avec vos paramètres
vim terraform.tfvars
```

Variables importantes :

```hcl
# ID de l'OMI Talos créée précédemment
talos_omi_id = "ami-xxxxxxxx"

# Type d'instance pour les control-planes
controlplane_vm_type = "tinav6.c4r8p2"

# Type d'instance pour les workers
worker_vm_type = "tinav6.c4r8p2"

# Nombre de workers
worker_count = 2

# CIDR autorisé pour l'accès bastion (votre IP publique)
bastion_allowed_ssh_cidr = "203.0.113.0/32"
```

Déployer l'infrastructure :

```bash
# Initialiser Terraform
terraform init

# Planifier les changements
terraform plan

# Appliquer
terraform apply
```

Récupérez les outputs Terraform :

```bash
# Endpoint du Load Balancer
terraform output kubernetes_api_endpoint

# IPs des control-planes
terraform output controlplane_ips

# IPs des workers
terraform output worker_ips
```

### 4. Bootstrap du cluster Kubernetes

Connectez-vous au bastion (ou depuis votre poste si vous avez la connectivité) :

```bash
# Variables d'environnement
export CLUSTER_NAME="talos-prod"
export KUBE_LBU="internal-talos-prod-k8s-lb-XXXXXXXXX.eu-west-2.lbu.outscale.com"

# Générer les configurations Talos
talosctl gen config "$CLUSTER_NAME" "https://$KUBE_LBU:6443" \
  --output-dir ./_out \
  --additional-sans "$KUBE_LBU" \
  --config-patch @cilium-patch.yaml

# Configurer talosctl
talosctl --talosconfig ./_out/talosconfig config endpoint 10.0.1.10 10.0.2.11 10.0.3.12
talosctl --talosconfig ./_out/talosconfig config node 10.0.1.10 10.0.2.11 10.0.3.12

# Appliquer la config aux control-planes
talosctl --talosconfig ./_out/talosconfig \
  --nodes 10.0.1.10,10.0.2.11,10.0.3.12 \
  apply-config --insecure \
  --file ./_out/controlplane.yaml

# Attendre 2 minutes que les nœuds redémarrent

# Bootstrap etcd (une seule fois sur le premier nœud)
talosctl --talosconfig ./_out/talosconfig \
  --nodes 10.0.1.10 \
  --endpoints 10.0.1.10 \
  bootstrap

# Appliquer la config aux workers
talosctl --talosconfig ./_out/talosconfig apply-config --insecure \
  --nodes 10.0.1.20 --file ./_out/worker.yaml

talosctl --talosconfig ./_out/talosconfig apply-config --insecure \
  --nodes 10.0.2.21 --file ./_out/worker.yaml
```

Récupérer le kubeconfig :

```bash
talosctl --talosconfig ./_out/talosconfig \
  --nodes 10.0.1.10 \
  --endpoints 10.0.1.10 \
  kubeconfig ./_out/kubeconfig --force

export KUBECONFIG=$(pwd)/_out/kubeconfig
kubectl get nodes
```

Les nœuds apparaissent `NotReady` car le CNI n'est pas encore installé.

### 5. Installation du CNI Cilium

```bash
# Ajouter le repo Helm Cilium
helm repo add cilium https://helm.cilium.io/
helm repo update

# Installer Cilium avec les paramètres optimisés pour Talos (en cours d'écriture)
helm upgrade --install cilium cilium/cilium \
  --namespace kube-system \
  --set kubeProxyReplacement=true \
  --set kubeProxyReplacementHealthzBindAddr=0.0.0.0:10256 \
  --set k8sServiceHost=$KUBE_LBU \
  --set k8sServicePort=6443 \
  --set ipam.mode=kubernetes \
  --set routingMode=native \
  --set ipv4NativeRoutingCIDR=10.244.0.0/16 \
  --set autoDirectNodeRoutes=true \
  --set operator.replicas=1 \
  --set securityContext.privileged=true \
  --set mountBPFFs=true \
  --set bpf.hostRouting=true \
  --set bpf.autoMount.enabled=false \
  --set bpffs.enabled=false \
  --set cgroup.autoMount.enabled=false \
  --set cgroup.hostRoot=/sys/fs/cgroup \
  --set nodeinit.enabled=false \
  --set sysctl=false \
  --set cleanState=false \
  --set mtu=9001

# Vérifier le déploiement
kubectl -n kube-system get pods -l k8s-app=cilium

# Vérifier le statut Cilium
kubectl -n kube-system exec -it ds/cilium -- cilium status

# Les nœuds doivent maintenant être Ready
kubectl get nodes
```

Résultat attendu :

```bash
NAME            STATUS   ROLES           AGE   VERSION
talos-cp-1      Ready    control-plane   15m   v1.31.1
talos-cp-2      Ready    control-plane   12m   v1.31.1
talos-cp-3      Ready    control-plane   12m   v1.31.1
talos-worker-1  Ready    <none>          8m    v1.31.1
talos-worker-2  Ready    <none>          8m    v1.31.1
```

🎉 **Votre cluster Kubernetes Talos est opérationnel !**

## 📁 Structure du projet

```
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
- **Article de blog** : https://blog.stephane-robert.info/docs/cloud/outscale/cluster-kubernetes-talos/

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
