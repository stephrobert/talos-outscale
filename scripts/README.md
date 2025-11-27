# Script de Teardown OKS-CLI

Ce dossier contient un script Python pour nettoyer automatiquement tous les clusters et projets créés avec OKS-CLI.

## Script disponible

### `teardown-oks.py` (Python)

Script Python robuste pour le teardown complet avec attente de la suppression des clusters.

#### Installation des dépendances

Le script utilise uniquement des modules Python standards (pas de dépendances externes).

#### Usage

```bash
# Avec confirmation interactive et attente de la suppression des clusters
python teardown-oks.py --profile student02

# En mode dry-run (simulation, aucune suppression réelle)
python teardown-oks.py --profile student02 --dry-run

# Sans confirmation
python teardown-oks.py --profile student02 --force

# Sans attendre la suppression complète des clusters (plus rapide mais risqué)
python teardown-oks.py --profile student02 --no-wait

# Avec timeout personnalisé (15 minutes par cluster au lieu de 10)
python teardown-oks.py --profile student02 --timeout 900

# Combinaison d'options
python teardown-oks.py --profile student02 --force --timeout 900
```

#### Options

| Option | Description |
|--------|-------------|
| `--profile` | **(Requis)** Nom du profil OKS-CLI à utiliser |
| `--dry-run` | Simule les suppressions sans les exécuter (pour tester) |
| `--force` | Ne demande pas de confirmation avant de supprimer |
| `--no-wait` | Ne pas attendre la suppression complète des clusters |
| `--timeout N` | Temps maximum d'attente pour chaque cluster en secondes (défaut: 600) |

#### Fonctionnalités

- ✅ **Attente intelligente** : Vérifie que chaque cluster est complètement supprimé avant de continuer
- ✅ Mode dry-run pour tester sans supprimer
- ✅ Confirmation interactive avec récapitulatif
- ✅ Statistiques détaillées en fin d'exécution
- ✅ Gestion robuste des erreurs et timeouts
- ✅ Support de Ctrl+C pour annuler
- ✅ Output JSON parsé correctement
- ✅ Logs colorés et structurés
- ✅ Polling automatique pour vérifier la suppression des clusters

---

## Workflow de suppression

Le script suit ce workflow :

1. **Validation du profil** : Vérifie que le profil existe dans `~/.oks_cli/config.json`
2. **Liste des projets** : Récupère tous les projets du profil
3. **Pour chaque projet** :
   - Liste tous les clusters
   - **Supprime chaque cluster individuellement**
   - **Attend que chaque cluster soit complètement supprimé** (polling toutes les 10 secondes)
   - Supprime le projet (uniquement quand tous les clusters sont supprimés)
4. **Rapport final** : Affiche un résumé des opérations

### ⚠️ Pourquoi attendre ?

La suppression des clusters prend du temps (plusieurs minutes). Si on supprime le projet avant que les clusters soient complètement supprimés, cela peut causer des erreurs. Le script attend donc automatiquement :

- Vérifie toutes les 10 secondes si le cluster existe encore
- Affiche un message de progression toutes les 30 secondes
- Timeout après 10 minutes par défaut (configurable avec `--timeout`)

## Exemples de sortie

### Mode normal avec attente

```bash
python teardown-oks.py --profile student02
```

```text
[INFO] === Début du teardown pour le profil: student02 ===

[INFO] Récupération de la liste des projets...
[INFO] Nombre de projets trouvés: 2

[WARNING] ══════════════════════════════════════════════════════════════════════
[WARNING] ATTENTION: Vous êtes sur le point de supprimer:
[WARNING]   • 2 projet(s)
[WARNING]   • 3 cluster(s)
[WARNING]   • Profil: student02
[WARNING] ══════════════════════════════════════════════════════════════════════

Êtes-vous sûr de vouloir continuer ? (oui/non): oui

[INFO] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[INFO] [1/2] Traitement du projet: my-project (statut: ready)
[INFO] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[INFO] Récupération des clusters du projet 'my-project'...
[INFO] Nombre de clusters à supprimer: 2

[INFO]   ➜ Suppression du cluster: prod-cluster (ID: clus-123abc, statut: running)
[SUCCESS]     ✓ Commande de suppression envoyée pour le cluster 'prod-cluster'
[INFO]     ⏳ Attente de la suppression complète du cluster 'prod-cluster'...
[INFO]     ⏳ Toujours en attente... (30/600s)
[INFO]     ⏳ Toujours en attente... (60/600s)
[SUCCESS]     ✓ Cluster 'prod-cluster' complètement supprimé (après 75s)

[INFO]   ➜ Suppression du cluster: dev-cluster (ID: clus-456def, statut: running)
[SUCCESS]     ✓ Commande de suppression envoyée pour le cluster 'dev-cluster'
[INFO]     ⏳ Attente de la suppression complète du cluster 'dev-cluster'...
[SUCCESS]     ✓ Cluster 'dev-cluster' complètement supprimé (après 42s)

[INFO] Suppression du projet: my-project
[SUCCESS] ✓ Projet 'my-project' supprimé avec succès

[INFO] ═══════════════════════════════════════════════════════════════════════
[SUCCESS] === Teardown terminé pour le profil: student02 ===
[INFO] ═══════════════════════════════════════════════════════════════════════

[INFO] Résumé:
[INFO]   • Clusters supprimés: 3
[INFO]   • Projets supprimés: 2
```

### Mode dry-run

```bash
python teardown-oks.py --profile student02 --dry-run
```

```text
[INFO] [DRY-RUN] === Début du teardown pour le profil: student02 ===

[INFO] Récupération de la liste des projets...
[INFO] Nombre de projets trouvés: 2

[INFO] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[INFO] [1/2] Traitement du projet: my-project (statut: ready)
[INFO] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[INFO] Récupération des clusters du projet 'my-project'...
[INFO] Nombre de clusters à supprimer: 1

[INFO]   ➜ [DRY-RUN] Suppression du cluster: test-cluster (ID: clus-123abc, statut: running)
[WARNING]     Mode dry-run activé - aucune suppression réelle

[INFO] [DRY-RUN] Suppression du projet: my-project
[WARNING] Mode dry-run activé - aucune suppression réelle

[INFO] ═══════════════════════════════════════════════════════════════════════
[SUCCESS] [DRY-RUN] === Teardown terminé pour le profil: student02 ===
[INFO] ═══════════════════════════════════════════════════════════════════════

[INFO] Résumé:
[INFO]   • Clusters supprimés: 1
[INFO]   • Projets supprimés: 2
```

## Sécurité et bonnes pratiques

### ⚠️ Avertissements

- **Ces scripts suppriment définitivement** tous les clusters et projets
- **Aucune sauvegarde automatique** n'est effectuée
- **Les données des clusters seront perdues** (sauf si vous avez des backups)

### ✅ Recommandations

1. **Toujours tester avec `--dry-run` d'abord** (version Python)
2. **Vérifier le profil** avant d'exécuter
3. **Sauvegarder les kubeconfigs** si nécessaire
4. **Documenter les ressources importantes** avant suppression
5. **Utiliser la confirmation interactive** en production

### 🔒 Vérification du profil

Avant d'exécuter les scripts, vérifiez votre profil :

```bash
# Voir les profils disponibles
cat ~/.oks_cli/config.json | jq 'keys'

# Tester le profil
oks-cli --profile student02 project list
```

## Cas d'usage

### Nettoyage après tests

```bash
# Mode dry-run pour vérifier
python teardown-oks.py --profile test-env --dry-run

# Si tout est OK, exécuter
python teardown-oks.py --profile test-env
```

### Nettoyage automatisé (CI/CD)

```bash
# Dans un pipeline, sans confirmation et sans attente (plus rapide)
python teardown-oks.py --profile ci-temp --force --no-wait
```

### Nettoyage avec timeout long

```bash
# Pour des gros clusters qui prennent plus de temps
python teardown-oks.py --profile production --timeout 1200
```

## Dépannage

### Le profil n'existe pas

```text
[ERROR] Le profil 'student02' n'existe pas ou n'est pas valide
```

**Solution** : Vérifiez `~/.oks_cli/config.json` et assurez-vous que le profil existe.

### oks-cli non trouvé

```text
[ERROR] oks-cli n'est pas installé ou n'est pas dans le PATH
```

**Solution** : Installez oks-cli ou ajoutez-le à votre PATH.

### Timeout lors de la suppression d'un cluster

```text
[WARNING]     ⚠ Timeout atteint pour le cluster 'my-cluster' après 600s
```

**Solution** :

- Augmentez le timeout avec `--timeout 1200` (20 minutes)
- Vérifiez l'état du cluster manuellement avec `oks-cli cluster list`
- Le projet pourra ne pas se supprimer si le cluster existe encore

### Échec de suppression d'un projet

```text
[ERROR] ✗ Échec de la suppression du projet 'my-project'
[WARNING] Le projet contient peut-être encore des ressources
```

**Solution** :

- Vérifiez que tous les clusters sont complètement supprimés
- Utilisez `--timeout` plus élevé pour laisser plus de temps
- Vérifiez manuellement les ressources restantes avec `oks-cli cluster list --project-name my-project`

### Interruption du script

Appuyez sur `Ctrl+C` pour interrompre proprement le script Python. Le script Bash peut être interrompu de la même manière, mais la gestion est moins propre.

## Développement

### Structure du code Python

```python
# Classes de données
@dataclass Cluster    # Représente un cluster
@dataclass Project    # Représente un projet

# Fonctions principales
get_projects()        # Liste les projets
get_clusters()        # Liste les clusters d'un projet
delete_cluster()      # Supprime un cluster
delete_project()      # Supprime un projet
teardown()           # Orchestration principale

# Utilitaires
run_oks_command()    # Wrapper pour exécuter oks-cli
confirm_teardown()   # Demande confirmation
log_*()              # Fonctions de logging
```

### Personnalisation

Vous pouvez modifier les scripts selon vos besoins :

- Changer les temps d'attente
- Ajouter des filtres sur les noms de projets
- Ajouter des exports de configuration avant suppression
- Intégrer des webhooks de notification

## Licence

Ces scripts font partie du projet talos-outscale et suivent la même licence.
