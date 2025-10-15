# Plan de présentation - TimescaleDB (40 minutes)

## 🎯 Objectif global
Montrer concrètement comment TimescaleDB résout les problèmes de séries temporelles à grande échelle, avec un cas pratique ludique et un retour d'expérience production.

---

## 1. Introduction (2 min)

### Message clé
Présentation rapide et accroche avec le contexte réel

### Contenu
- Qui je suis : David, DevOps/Dev Backend chez Karnott
- On gère des données de tracteurs et d'engins agricoles
- Spoiler : on va parler de la Petite Souris aujourd'hui !

### Slide
- Titre de la présentation
- Photo/logo si besoin
- Contact GitHub

**Timing : 2 min**

---

## 2. Retour d'expérience Karnott (4 min)

### Message clé
Voilà pourquoi je vous parle de TimescaleDB : on l'utilise vraiment en prod avec des volumes massifs

### Contenu
**Les chiffres :**
- ~30 milliards de points de données
- ~5 To de stockage (11 To sans compression)
- Dizaines de millions de nouvelles données par jour
- Millions de requêtes par jour
- PostgreSQL + TimescaleDB + PostGIS

**Les cas d'usage :**
- Tracking GPS des engins agricoles
- Calcul des surfaces travaillées
- Répartition des travaux
- Analyse temporelle des données

**Pourquoi TimescaleDB ?**
- Besoin d'agrégations temporelles rapides
- Volume qui explose
- Requêtes type "moyenne sur les 7 derniers jours par heure"
- Rétention et compression des données historiques

### Slides
- Slide avec les chiffres clés (gros et visibles)
- Éventuellement un screenshot de dashboard/métriques
- Slide "Le problème à résoudre"

**Timing : 4 min**

---

## 3. Le cas de la Petite Souris (5 min)

### Message clé
Pour vous montrer concrètement, on va prendre un cas ludique mais avec les mêmes problématiques

### Contenu
**Le contexte business :**
- 2 milliards d'enfants dans le monde
- ~20 dents de lait par enfant
- Pic d'activité entre 6 et 12 ans
- Des millions de transactions par nuit
- Besoin de tracking, analytics, optimisation

**Le schéma de données :**
```sql
tooth_loss (
    time,           -- Quand la dent est tombée
    child_id,       -- Quel enfant
    tooth_number,   -- Quelle dent (1-20)
    country,        -- Pays
    city,           -- Ville
    price,          -- Prix payé
    payment_method  -- Méthode de paiement
)
```

**Les questions métier :**
- Quel est le prix moyen par mois/pays ?
- Quelles sont les heures de pointe ?
- Quelles villes sont les plus généreuses ?
- Tendances d'inflation du prix de la dent ?
- Optimisation des tournées

**Le problème PostgreSQL classique :**
- Table qui grossit exponentiellement
- Requêtes qui ralentissent
- Partition manuelle complexe
- Pas de compression native efficace

### Démo 1 : PostgreSQL classique
```sql
-- Création table classique
CREATE TABLE tooth_loss_classic (
    time TIMESTAMPTZ NOT NULL,
    child_id INTEGER,
    tooth_number INTEGER,
    country VARCHAR(2),
    city VARCHAR(100),
    price DECIMAL(10,2),
    payment_method VARCHAR(20)
);

-- Insertion de 10M de lignes
INSERT INTO tooth_loss_classic 
SELECT ...;

-- Requête simple qui rame
SELECT 
    date_trunc('month', time) AS month,
    AVG(price) 
FROM tooth_loss_classic 
WHERE time > NOW() - INTERVAL '1 year'
GROUP BY month;

-- EXPLAIN ANALYZE pour montrer la lenteur
```

### Slides
- Slide contexte business avec icônes sympas
- Slide schéma de données
- Slide "Les questions métier"
- Terminal pour la démo

**Timing : 5 min**

---

## 4. TimescaleDB : Les bases (8 min)

### Message clé
TimescaleDB = PostgreSQL + superpowers pour les séries temporelles

### Contenu
**Qu'est-ce que TimescaleDB ?**
- Extension PostgreSQL (pas un fork !)
- 100% compatible avec PostgreSQL
- Spécialisé séries temporelles
- Open source

**Les concepts clés :**
- **Hypertable** : table virtuelle qui partitionne automatiquement
- **Chunks** : partitions sous le capot (par défaut 7 jours)
- Transparent pour l'utilisateur (SQL standard)

### Démo 2 : Installation et première hypertable

**Live coding :**
```sql
-- Activer l'extension
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Créer la table
CREATE TABLE tooth_loss (
    time TIMESTAMPTZ NOT NULL,
    child_id INTEGER,
    tooth_number INTEGER,
    country VARCHAR(2),
    city VARCHAR(100),
    price DECIMAL(10,2),
    payment_method VARCHAR(20)
);

-- Transformer en hypertable
SELECT create_hypertable('tooth_loss', 'time');

-- Vérifier les chunks
SELECT * FROM timescaledb_information.chunks;
```

**Génération de données :**
```sql
-- Script d'insertion massive (10M+ lignes)
INSERT INTO tooth_loss 
SELECT 
    time,
    (random() * 1000000)::int as child_id,
    (random() * 20 + 1)::int as tooth_number,
    (ARRAY['FR', 'DE', 'ES', 'IT', 'US', 'UK'])[ceil(random()*6)] as country,
    'City_' || (random() * 1000)::int as city,
    (random() * 10 + 0.5)::decimal(10,2) as price,
    (ARRAY['cash', 'coin', 'gift'])[ceil(random()*3)] as payment_method
FROM generate_series(
    NOW() - INTERVAL '5 years',
    NOW(),
    INTERVAL '3 seconds'  -- Pour avoir des millions de lignes
) AS time;

-- Vérifier
SELECT COUNT(*) FROM tooth_loss;
SELECT pg_size_pretty(pg_total_relation_size('tooth_loss'));
```

**Montrer les chunks créés automatiquement :**
```sql
SELECT 
    chunk_name,
    range_start,
    range_end,
    pg_size_pretty(total_bytes) as size
FROM timescaledb_information.chunks
WHERE hypertable_name = 'tooth_loss'
ORDER BY range_start DESC
LIMIT 10;
```

### Slides
- Slide "Qu'est-ce que TimescaleDB"
- Slide schéma conceptuel hypertable/chunks
- Terminal pour live coding

**Timing : 8 min**

---

## 5. Requêtes temporelles (10 min)

### Message clé
time_bucket : le superpouvoir des agrégations temporelles

### Contenu
**Le problème avec date_trunc :**
- Limité aux intervalles standards
- Verbeux
- Pas optimisé pour les hypertables

**time_bucket à la rescousse :**
- Agrégation flexible
- Optimisé pour TimescaleDB
- Peut faire des intervalles custom

### Démo 3 : Exemples de requêtes métier

**Exemple 1 : Prix moyen par mois**
```sql
-- Avec date_trunc (old way)
SELECT 
    date_trunc('month', time) AS month,
    AVG(price) as avg_price,
    COUNT(*) as transactions
FROM tooth_loss
WHERE time > NOW() - INTERVAL '1 year'
GROUP BY month
ORDER BY month;

-- Avec time_bucket (TimescaleDB way)
SELECT 
    time_bucket('1 month', time) AS month,
    AVG(price) as avg_price,
    COUNT(*) as transactions
FROM tooth_loss
WHERE time > NOW() - INTERVAL '1 year'
GROUP BY month
ORDER BY month;

-- EXPLAIN ANALYZE des deux pour comparer
```

**Exemple 2 : Pics d'activité par heure**
```sql
SELECT 
    time_bucket('1 hour', time) AS hour,
    country,
    COUNT(*) as teeth_collected,
    AVG(price) as avg_price
FROM tooth_loss
WHERE time > NOW() - INTERVAL '7 days'
GROUP BY hour, country
HAVING COUNT(*) > 100
ORDER BY teeth_collected DESC
LIMIT 20;
```

**Exemple 3 : Top villes généreuses**
```sql
SELECT 
    city,
    country,
    COUNT(*) as total_teeth,
    AVG(price) as avg_price,
    MIN(price) as min_price,
    MAX(price) as max_price
FROM tooth_loss
WHERE time > NOW() - INTERVAL '1 year'
GROUP BY city, country
HAVING COUNT(*) > 1000
ORDER BY avg_price DESC
LIMIT 10;
```

**Exemple 4 : Évolution hebdomadaire avec window functions**
```sql
SELECT 
    time_bucket('1 week', time) AS week,
    AVG(price) as avg_price,
    LAG(AVG(price)) OVER (ORDER BY time_bucket('1 week', time)) as prev_week,
    ROUND(
        (AVG(price) - LAG(AVG(price)) OVER (ORDER BY time_bucket('1 week', time))) 
        / LAG(AVG(price)) OVER (ORDER BY time_bucket('1 week', time)) * 100,
        2
    ) as variation_percent
FROM tooth_loss
WHERE time > NOW() - INTERVAL '6 months'
GROUP BY week
ORDER BY week DESC;
```

**Bonus : Intervalle custom**
```sql
-- Agrégation toutes les 6 heures
SELECT 
    time_bucket('6 hours', time) AS period,
    COUNT(*) as transactions,
    AVG(price) as avg_price
FROM tooth_loss
WHERE time > NOW() - INTERVAL '1 month'
GROUP BY period
ORDER BY period DESC;
```

### Slides
- Slide "Le problème des agrégations temporelles"
- Terminal pour les exemples
- Éventuellement slide avec résultats en graphique

**Timing : 10 min**

---

## 6. Optimisations avancées (10 min)

### Message clé
TimescaleDB ne fait pas que des requêtes rapides, il optimise aussi le stockage et la maintenance

### Contenu

### 6.1 Compression (3 min)

**Pourquoi ?**
- Réduction drastique du stockage (jusqu'à 90%)
- Données anciennes rarement modifiées
- Garde les performances en lecture

### Live coding : Compression
```sql
-- État actuel
SELECT 
    pg_size_pretty(before_compression_total_bytes) as before,
    pg_size_pretty(after_compression_total_bytes) as after,
    ROUND(100 - (after_compression_total_bytes::float / 
          before_compression_total_bytes::float * 100), 1) as compression_ratio
FROM timescaledb_information.compression_settings
WHERE hypertable_name = 'tooth_loss';

-- Activer la compression
ALTER TABLE tooth_loss SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'country',
    timescaledb.compress_orderby = 'time DESC'
);

-- Compresser les chunks > 7 jours
SELECT compress_chunk(chunk)
FROM timescaledb_information.chunks
WHERE hypertable_name = 'tooth_loss'
  AND range_end < NOW() - INTERVAL '7 days';

-- Voir le résultat
SELECT 
    chunk_name,
    compression_status,
    pg_size_pretty(before_compression_total_bytes) as before,
    pg_size_pretty(after_compression_total_bytes) as after
FROM timescaledb_information.chunks
WHERE hypertable_name = 'tooth_loss'
  AND compression_status = 'Compressed'
LIMIT 5;

-- Policy automatique
SELECT add_compression_policy('tooth_loss', INTERVAL '7 days');
```

### 6.2 Retention Policies (2 min)

**Pourquoi ?**
- Pas besoin de garder toutes les données éternellement
- Libération automatique d'espace
- Maintenance simplifiée

### Live coding : Retention
```sql
-- Supprimer automatiquement les données > 3 ans
SELECT add_retention_policy('tooth_loss', INTERVAL '3 years');

-- Vérifier la policy
SELECT * FROM timescaledb_information.jobs
WHERE proc_name = 'policy_retention';

-- Voir ce qui sera supprimé
SELECT 
    chunk_name,
    range_start,
    range_end,
    pg_size_pretty(total_bytes) as size
FROM timescaledb_information.chunks
WHERE hypertable_name = 'tooth_loss'
  AND range_end < NOW() - INTERVAL '3 years';
```

### 6.3 Continuous Aggregates (5 min)

**Pourquoi ?**
- Pré-calculer les agrégations coûteuses
- Mise à jour automatique
- Requêtes instantanées sur les données agrégées

### Live coding : Continuous Aggregates
```sql
-- Créer une vue matérialisée continue
CREATE MATERIALIZED VIEW daily_stats
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 day', time) AS day,
    country,
    COUNT(*) as teeth_count,
    AVG(price) as avg_price,
    MIN(price) as min_price,
    MAX(price) as max_price,
    SUM(price) as total_revenue
FROM tooth_loss
GROUP BY day, country
WITH NO DATA;

-- Rafraîchir (première fois)
CALL refresh_continuous_aggregate('daily_stats', NULL, NULL);

-- Policy de rafraîchissement automatique
SELECT add_continuous_aggregate_policy('daily_stats',
    start_offset => INTERVAL '1 month',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour'
);

-- Utiliser la vue (super rapide !)
SELECT 
    day,
    country,
    teeth_count,
    ROUND(avg_price, 2) as avg_price
FROM daily_stats
WHERE day > NOW() - INTERVAL '3 months'
  AND country IN ('FR', 'US', 'DE')
ORDER BY day DESC, country;

-- Comparer les performances
EXPLAIN ANALYZE
SELECT 
    time_bucket('1 day', time) AS day,
    country,
    COUNT(*) as teeth_count,
    AVG(price) as avg_price
FROM tooth_loss
WHERE time > NOW() - INTERVAL '3 months'
  AND country IN ('FR', 'US', 'DE')
GROUP BY day, country;

-- vs

EXPLAIN ANALYZE
SELECT day, country, teeth_count, avg_price
FROM daily_stats
WHERE day > NOW() - INTERVAL '3 months'
  AND country IN ('FR', 'US', 'DE');
```

### Slides
- Slide "Les 3 piliers de l'optimisation"
- Terminal pour le live coding
- Slide avec comparaison avant/après (chiffres)

**Timing : 10 min**

---

## 7. Conclusion (1 min)

### Message clé
TimescaleDB = la solution pour les séries temporelles à grande échelle

### Contenu
**Points clés à retenir :**
- Extension PostgreSQL, pas besoin de changer de stack
- Hypertables = partitionnement automatique
- time_bucket = agrégations temporelles puissantes
- Compression + Retention + Continuous Aggregates = stack complète
- Production-ready (utilisé par des milliers d'entreprises)

**Pièges à éviter :**
- Bien choisir la colonne de temps (TIMESTAMPTZ !)
- Adapter la taille des chunks selon vos besoins
- Tester la compression avant la prod
- Ne pas oublier les index sur les colonnes filtrées

**Ressources :**
- docs.timescale.com
- github.com/timescale/timescaledb
- Repo de cette présentation : [votre repo]

### Slide
- Slide récap des points clés
- Slide avec les ressources
- Slide "Merci ! Questions ?"

**Timing : 1 min + questions**

---

## 🎬 Récapitulatif timing

| Section | Durée | Cumulé |
|---------|-------|--------|
| 1. Introduction | 2 min | 2 min |
| 2. Retour Karnott | 4 min | 6 min |
| 3. Cas Petite Souris | 5 min | 11 min |
| 4. Les bases | 8 min | 19 min |
| 5. Requêtes temporelles | 10 min | 29 min |
| 6. Optimisations | 10 min | 39 min |
| 7. Conclusion | 1 min | 40 min |

**Total : 40 minutes**

---

## 📝 Notes techniques

### Setup avant la présentation
```bash
# Docker avec PostgreSQL + TimescaleDB
docker run -d --name timescaledb \
  -p 5432:5432 \
  -e POSTGRES_PASSWORD=password \
  timescale/timescaledb:latest-pg16

# Connexion
psql -h localhost -U postgres
```

### Terminal
- Police : 18-20pt minimum
- Thème : fond sombre, contraste élevé
- Historique : garder les commandes importantes visibles

### Backup
- Screenshots de chaque démo
- Dumps SQL à différents états
- VM/Docker tout-en-un

### Interaction audience
- "À votre avis, combien de lignes on a là ?"
- "Selon vous, quel gain de compression ?"
- "Qui utilise déjà PostgreSQL ici ?"