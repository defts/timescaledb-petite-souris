# Comment la Petite Souris gère ses milliards de dents avec TimescaleDB

> Présentation pour le meetup du 13 novembre 2024  
> Par David Torres Dias - DevOps chez Karnott

## 📋 Vue d'ensemble

Cette présentation de 40 minutes explore TimescaleDB à travers un cas d'usage ludique : le système d'information de la Petite Souris. De la mise en place aux optimisations avancées, avec des démos live et un retour d'expérience production sur 30 milliards de données.

## 🎯 Objectifs de la présentation

- Comprendre les limites de PostgreSQL pour les séries temporelles
- Découvrir les concepts clés de TimescaleDB (hypertables, chunks, time_bucket)
- Maîtriser les optimisations : compression, retention policies, continuous aggregates
- Apprendre des retours d'expérience production

## 🏗️ Structure du projet

```
.
├── README.md                          # Ce fichier
├── Makefile                           # ⭐ Commandes simplifiées (make help)
├── MAKEFILE_GUIDE.md                  # Guide complet du Makefile
├── CHANGELOG.md                       # Journal des modifications
├── RETROPLANNING.md                   # Planning jusqu'au 13 novembre
├── PLAN_PRESENTATION.md               # Plan détaillé avec timing
├── slides.md                          # Présentation Slidev
├── docker-compose.yml                 # Stack PostgreSQL + TimescaleDB
├── package.json                       # Config Slidev
├── .gitignore
├── scripts/
│   ├── 01-setup.sql                   # Création DB et hypertable
│   ├── 02-generate-data.sql           # Génération données massives
│   ├── 03-queries.sql                 # Requêtes de démo
│   ├── 04-compression.sql             # Exemples compression
│   ├── 05-retention.sql               # Retention policies
│   └── 06-continuous-aggregates.sql   # Continuous aggregates
└── backups/                           # Dumps SQL pour backup démo
```

## 🚀 Quick Start

### Prérequis

- Docker et Docker Compose
- Node.js 18+ (pour Slidev)
- psql (client PostgreSQL)
- make (optionnel mais recommandé)

### Installation rapide avec Makefile

Le projet inclut un **Makefile** pour simplifier toutes les opérations :

```bash
# 1. Cloner le repo
git clone https://github.com/defts/timescaledb-petite-souris
cd timescaledb-petite-souris

# 2. Voir toutes les commandes disponibles
make help

# 3. Préparer la démo complète (Docker + setup + données)
make demo

# 4. Lancer la présentation
make slides
```

**C'est tout !** En une commande (`make demo`), vous avez :
- ✅ TimescaleDB démarré
- ✅ Extension activée et hypertable créée
- ✅ ~100 millions de lignes générées
- ✅ Prêt pour les démos live

### Installation manuelle (sans Makefile)

<details>
<summary>Cliquez pour voir les étapes manuelles</summary>

1. **Cloner le repo**
```bash
git clone https://github.com/defts/timescaledb-petite-souris
cd timescaledb-petite-souris
```

2. **Lancer TimescaleDB**
```bash
docker-compose up -d
```

3. **Vérifier que la DB est prête**
```bash
docker-compose logs -f timescaledb
# Attendre le message "database system is ready to accept connections"
```

4. **Se connecter à la base**
```bash
PGPASSWORD=password psql -h localhost -U postgres -d postgres
```

5. **Installer Slidev**
```bash
npm install
```

6. **Lancer la présentation**
```bash
npm run dev
```

La présentation sera accessible sur `http://localhost:3030`

</details>

## 📊 Démos et scripts

### Avec le Makefile (recommandé)

```bash
make 01    # Setup initial (extension + hypertable)
make 02    # Génération de données (~100M lignes, 2-3 min)
make 03    # Requêtes temporelles (time_bucket)
make 04    # Compression des données
make 05    # Retention policies
make 06    # Continuous aggregates

# Ou tout d'un coup :
make all
```

### Commandes Makefile utiles

```bash
make help         # Afficher toutes les commandes disponibles
make demo         # Setup complet pour la démo (start + 01 + 02)
make quick-demo   # Demo rapide avec moins de données
make stats        # Afficher les stats de la base
make psql         # Se connecter à psql
make reset        # Tout supprimer et recommencer
```

### Sans Makefile (mode manuel)

<details>
<summary>Cliquez pour voir les commandes manuelles</summary>

#### Démo 1 : Setup initial (Section 4)

```bash
PGPASSWORD=password psql -h localhost -U postgres -d postgres -f scripts/01-setup.sql
```

Crée :
- L'extension TimescaleDB
- La table `tooth_loss`
- La transformation en hypertable

#### Démo 2 : Génération de données (Section 4)

```bash
PGPASSWORD=password psql -h localhost -U postgres -d postgres -f scripts/02-generate-data.sql
```

Génère ~50 millions de lignes sur 5 ans (ajustable dans le script)

⏱️ **Temps d'exécution :** ~2-3 minutes selon votre machine

### Démo 3 : Requêtes temporelles (Section 5)

```bash
psql -h localhost -U postgres -d postgres -f scripts/03-queries.sql
```

Exemples de requêtes avec `time_bucket` :
- Prix moyen par mois
- Pics d'activité par heure
- Top villes généreuses
- Évolution avec window functions

### Démo 4 : Compression (Section 6.1)

```bash
psql -h localhost -U postgres -d postgres -f scripts/04-compression.sql
```

Démontre :
- Activation de la compression
- Compression manuelle des chunks
- Policy automatique
- Gains observés (~90% de réduction)

### Démo 5 : Retention Policies (Section 6.2)

```bash
psql -h localhost -U postgres -d postgres -f scripts/05-retention.sql
```

Montre :
- Suppression automatique des vieilles données
- Configuration des policies
- Monitoring

### Démo 6 : Continuous Aggregates (Section 6.3)

```bash
psql -h localhost -U postgres -d postgres -f scripts/06-continuous-aggregates.sql
```

Illustre :
- Création de vues matérialisées continues
- Rafraîchissement automatique
- Comparaison de performances

## 🎤 Présentation

### Mode développement

```bash
npm run dev
```

### Mode présentation

```bash
npm run build
npm run preview
```

### Export PDF

```bash
npm run export
```

Génère `slides-export.pdf` dans le dossier racine

### Raccourcis clavier Slidev

- `→` / `←` : Navigation entre slides
- `o` : Vue d'ensemble
- `d` : Mode sombre
- `f` : Plein écran
- `c` : Mode caméra (affiche les notes)
- `p` : Mode présentateur

## 🔧 Configuration

### Ajuster le volume de données

Dans `scripts/02-generate-data.sql`, modifier l'intervalle :

```sql
-- Pour 10M de lignes (~1.5 ans)
FROM generate_series(
    NOW() - INTERVAL '1.5 years',
    NOW(),
    INTERVAL '5 seconds'
) AS time;

-- Pour 100M de lignes (~5 ans)  - UTILISÉ PAR DÉFAUT
FROM generate_series(
    NOW() - INTERVAL '5 years',
    NOW(),
    INTERVAL '1.5 seconds'
) AS time;
```

### Personnaliser les slides

Modifier `slides.md` avec la syntaxe Markdown + Slidev.

Documentation : https://sli.dev

## 🎓 Le contexte : La Petite Souris SA

### Les chiffres du business

- **2 milliards** d'enfants dans le monde
- **~20 dents** de lait par enfant
- **Millions** de transactions par nuit
- Pic d'activité entre 6 et 12 ans

### Le schéma de données

```sql
tooth_loss (
    time            TIMESTAMPTZ NOT NULL,  -- Timestamp de perte de dent
    child_id        INTEGER,               -- ID de l'enfant
    tooth_number    INTEGER,               -- Numéro de la dent (1-20)
    country         VARCHAR(2),            -- Code pays
    city            VARCHAR(100),          -- Ville
    price           DECIMAL(10,2),         -- Prix payé par la souris
    payment_method  VARCHAR(20)            -- cash, coin, gift
)
```

### Les questions métier

1. Quel est le prix moyen par mois/pays ?
2. Quelles sont les heures de pointe ?
3. Quelles villes sont les plus généreuses ?
4. Y a-t-il une inflation du prix de la dent ?
5. Comment optimiser les tournées nocturnes ?

## 📈 Retour d'expérience Karnott

### Contexte

Karnott développe des solutions IoT pour l'agriculture connectée : tracking GPS des engins agricoles, calcul des surfaces travaillées, répartition des travaux.

### Infrastructure

- **PostgreSQL 16 + TimescaleDB + PostGIS**
- **~30 milliards** de points de données
- **~5 To** de stockage (11 To sans compression)
- **Dizaines de millions** de nouvelles données par jour
- **Millions** de requêtes par jour

### Stack technique

- **Cloud :** Google Cloud Platform (Cloud SQL)
- **Orchestration :** Kubernetes (GKE)
- **Monitoring :** pgBadger, OpenTelemetry, Cloud Trace
- **CI/CD :** GitHub Actions
- **IaC :** Terraform

### Pourquoi TimescaleDB ?

1. **Performance :** Agrégations temporelles 10-100x plus rapides
2. **Compression :** ~90% de réduction du stockage
3. **Simplicité :** Extension PostgreSQL, pas de migration de stack
4. **Maintenance :** Partitionnement et rétention automatiques

### Les gains mesurés

| Métrique | Avant | Après | Gain |
|----------|-------|-------|------|
| Requête "avg sur 7j par heure" | ~12s | ~0.8s | **15x** |
| Stockage données > 1 an | 11 To | 1.2 To | **90%** |
| Temps de maintenance | 4h/mois | ~0h | **100%** |

## 🛠️ Commandes utiles

### Docker

```bash
# Démarrer la stack
docker-compose up -d

# Voir les logs
docker-compose logs -f

# Arrêter
docker-compose down

# Tout supprimer (DB incluse)
docker-compose down -v
```

### PostgreSQL

```bash
# Se connecter
psql -h localhost -U postgres -d postgres

# Lister les bases
\l

# Lister les tables
\dt

# Décrire une table
\d tooth_loss

# Quitter
\q
```

### Requêtes de monitoring

```sql
-- Taille de la hypertable
SELECT pg_size_pretty(hypertable_size('tooth_loss'));

-- Nombre de chunks
SELECT COUNT(*) FROM timescaledb_information.chunks 
WHERE hypertable_name = 'tooth_loss';

-- État de compression
SELECT 
    chunk_name,
    compression_status,
    pg_size_pretty(before_compression_total_bytes) as before,
    pg_size_pretty(after_compression_total_bytes) as after
FROM timescaledb_information.chunks
WHERE hypertable_name = 'tooth_loss';

-- Jobs actifs (compression, retention, etc.)
SELECT * FROM timescaledb_information.jobs;
```

## 🎯 Checklist jour J

### Avant le meetup (J-1)

- [ ] Répétition finale complète
- [ ] Export PDF de la présentation
- [ ] Préparer clé USB de backup
- [ ] Vérifier que Docker fonctionne
- [ ] Tester tous les scripts SQL
- [ ] Charger batterie du laptop à 100%

### Le matin du meetup

- [ ] Lancer Docker en local
- [ ] Exécuter scripts 01 et 02 (setup + données)
- [ ] Vérifier que psql fonctionne
- [ ] Augmenter taille police terminal (18-20pt)
- [ ] Tester vidéoprojecteur si possible

### 30 min avant

- [ ] Arriver sur place
- [ ] Brancher laptop + chargeur
- [ ] Tester vidéoprojecteur
- [ ] Tester connexion internet (si nécessaire)
- [ ] Lancer Docker si pas déjà fait
- [ ] Ouvrir terminal + Slidev
- [ ] Respirer 🧘

### Matériel

- [ ] Laptop chargé
- [ ] Chargeur
- [ ] Adaptateur vidéo (HDMI/USB-C/VGA)
- [ ] Clé USB backup
- [ ] Souris (optionnel)
- [ ] Notes papier
- [ ] Bouteille d'eau

## 📚 Ressources

### TimescaleDB

- [Documentation officielle](https://docs.timescale.com)
- [GitHub](https://github.com/timescale/timescaledb)
- [Blog Timescale](https://www.timescale.com/blog)
- [Tutoriels](https://docs.timescale.com/tutorials/latest/)

### PostgreSQL

- [Documentation PostgreSQL](https://www.postgresql.org/docs/)
- [pgBadger](https://pgbadger.darold.net/)

### Slidev

- [Documentation Slidev](https://sli.dev)
- [Exemples de thèmes](https://sli.dev/themes/gallery.html)

## 🐛 Troubleshooting

### La DB ne démarre pas

```bash
# Vérifier les logs
docker-compose logs timescaledb

# Recréer le container
docker-compose down -v
docker-compose up -d
```

### Impossible de se connecter à psql

```bash
# Vérifier que le container tourne
docker ps

# Vérifier les ports
netstat -an | grep 5432

# Tester la connexion
psql -h localhost -U postgres -d postgres
```

### Les données ne se génèrent pas

```bash
# Vérifier l'espace disque
df -h

# Réduire le volume dans 02-generate-data.sql
# Passer de INTERVAL '5 years' à '1 year'
```

### Slidev ne démarre pas

```bash
# Réinstaller les dépendances
rm -rf node_modules package-lock.json
npm install
npm run dev
```

## 🤝 Contribution

Cette présentation est open source ! N'hésitez pas à :

- 🐛 Reporter des bugs
- 💡 Suggérer des améliorations
- 🔧 Proposer des PRs
- ⭐ Star le repo si ça vous a plu !

## 📄 Licence

MIT - Faites-en ce que vous voulez !

## 👤 Auteur

**David Torres Dias**

- DevOps & Développeur Backend Go chez Karnott
- GitHub: [@davidtorresdias](https://github.com/davidtorresdias)
- Email: david@torresdias.fr

---

## 🙏 Remerciements

- L'équipe Karnott pour le retour d'expérience
- La communauté TimescaleDB
- Les organisateurs du meetup
- La Petite Souris pour son système d'information imaginaire 🐭🦷

---

**Bon meetup ! 🎉**