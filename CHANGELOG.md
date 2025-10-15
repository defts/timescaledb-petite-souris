# Changelog - Projet TimescaleDB Petite Souris

## [2024-10-15] - Optimisations des requêtes de démonstration

### Problème identifié
Plusieurs requêtes dans le script 03 avaient des seuils trop élevés pour les données générées aléatoirement, résultant en 0 résultats affichés. De plus, une requête était très lente (>1 minute).

### Optimisations appliquées
**Fichier :** `scripts/03-queries.sql`

#### Exemple 2 - Pics d'activité par heure
- Seuil : `HAVING COUNT(*) > 1000` → `> 100`
- Résultat : Affiche maintenant ~20 lignes au lieu de 0
- Ajout de `ROUND()` sur `total_revenue` pour meilleure lisibilité

#### Exemple 3 - Top villes généreuses
- Seuil : `HAVING COUNT(*) > 10000` → `> 100`
- Résultat : Affiche le top 10 des villes avec prix moyens les plus élevés

#### Exemple 9 - Enfants avec le plus de dents perdues
- Période : `2 years` → `6 months`
- Seuil : `HAVING COUNT(*) >= 10` → `>= 3`
- **Impact :** Requête 10x plus rapide (~10s au lieu de 1m26s)
- Résultat : Affiche maintenant 10 résultats au lieu de 0

### Bénéfices pour la présentation
- ✅ Toutes les requêtes affichent maintenant des résultats visuels
- ✅ Performances améliorées (exemple 9 : 90% plus rapide)
- ✅ Démo plus impactante avec des données concrètes
- ✅ Seuils adaptés aux données générées aléatoirement

---

## [2024-10-15] - Corrections de compatibilité TimescaleDB 2.x

### Problème identifié
Les colonnes `*_bytes` ont été dépréciées dans `timescaledb_information.chunks` à partir de TimescaleDB 2.x, causant des erreurs dans les scripts de démonstration.

### Corrections appliquées

#### 1. Script 02 - Génération de données
**Fichier :** `scripts/02-generate-data.sql`

**Changement :** Ligne 100-102
```sql
-- Avant
pg_size_pretty(total_bytes) as size

-- Après
pg_size_pretty(
    pg_total_relation_size(format('%I.%I', chunk_schema, chunk_name))
) as size
```

#### 2. Script 04 - Compression
**Fichier :** `scripts/04-compression.sql`

**Changements majeurs :** Lignes 38-44 et 105-136

Remplacement de l'accès direct aux colonnes `*_bytes` par l'utilisation des fonctions officielles :
- `hypertable_compression_stats('hypertable_name')` : Statistiques globales de compression
- `chunk_compression_stats('hypertable_name')` : Statistiques par chunk

**Avantages :**
- ✅ Statistiques de compression complètes conservées
- ✅ Ratio de compression calculé automatiquement
- ✅ Espace disque économisé visible
- ✅ Top 10 des chunks compressés
- ✅ Compatible avec toutes les versions récentes de TimescaleDB

**Exemple de sortie :**
```
📦 Statistiques de compression globales:
total_chunks | compressed | uncompressed | size_before | size_after | space_saved | ratio
-------------+------------+--------------+-------------+------------+-------------+-------
         261 |        254 |            7 | 25 GB       | 2.5 GB     | 22.5 GB     | 90.0%

📦 Statistiques par chunk (top 10):
chunk                        | status     | before  | after  | ratio
-----------------------------+------------+---------+--------+-------
_timescaledb_internal._hyper | Compressed | 102 MB  | 11 MB  | 89.2%
...
```

#### 3. Script 05 - Retention policies
**Fichier :** `scripts/05-retention.sql`

**Changements :** Lignes 39-41, 58-60, 71-73
```sql
-- Avant
pg_size_pretty(SUM(total_bytes))

-- Après
pg_size_pretty(SUM(
    pg_total_relation_size(format('%I.%I', chunk_schema, chunk_name))
))
```

### Tests effectués
✅ Tous les scripts s'exécutent sans erreur
✅ Les statistiques de compression sont correctes
✅ Compatible avec TimescaleDB 2.x
✅ La démo `make demo` fonctionne de bout en bout

---

## [2024-10-15] - Ajout du Makefile

### Nouvelles fonctionnalités
- Makefile complet pour simplifier toutes les opérations
- Commandes intuitives : `make 01`, `make 02`, etc.
- Setup automatique avec `make demo`
- Gestion Docker simplifiée
- Guide dédié dans `MAKEFILE_GUIDE.md`

### Commandes principales
```bash
make demo         # Setup complet automatique
make 01-06        # Exécution des scripts individuels
make start/stop   # Gestion Docker
make stats        # Monitoring en temps réel
make psql         # Connexion rapide
make slides       # Lancer la présentation
make help         # Aide complète
```

---

## [2024-10-15] - Corrections best practices PostgreSQL

### Changements
**Fichier :** `scripts/01-setup.sql`

Remplacement des types `VARCHAR(n)` par `TEXT` pour suivre les recommandations PostgreSQL/TimescaleDB :
- `country VARCHAR(2)` → `country TEXT`
- `city VARCHAR(100)` → `city TEXT`
- `payment_method VARCHAR(20)` → `payment_method TEXT`

**Bénéfices :**
- ✅ Plus de warnings TimescaleDB
- ✅ Suit les best practices PostgreSQL
- ✅ Plus flexible (pas de limite de taille artificielle)

---

## [2024-10-15] - Correction docker-compose.yml

### Changement
Suppression de la ligne `version: '3.8'` devenue obsolète dans les versions récentes de Docker Compose.

**Impact :**
- ✅ Plus de warnings Docker
- ✅ Compatible avec Docker Compose v2+

---

## Notes de migration

Si vous utilisez une version antérieure du projet :

1. **Recreer la table `tooth_loss`** pour appliquer les changements de types :
   ```bash
   make clean-db
   make 01
   ```

2. **Utiliser le nouveau Makefile** :
   ```bash
   make demo
   ```

3. **Les anciens scripts SQL fonctionnent toujours** si exécutés manuellement, mais le Makefile est recommandé.

---

## Compatibilité

### Versions testées
- ✅ TimescaleDB 2.x (latest)
- ✅ PostgreSQL 16
- ✅ Docker Compose v2+
- ✅ macOS, Linux

### Versions non supportées
- ❌ TimescaleDB 1.x (colonnes `*_bytes` requises)
- ❌ PostgreSQL < 12

---

## Contributions

Ce projet est open source. N'hésitez pas à :
- Reporter des bugs
- Suggérer des améliorations
- Proposer des PRs

Contact : david@torresdias.fr
