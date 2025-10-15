-- ============================================================================
-- Script 02: Génération de données massives
-- ============================================================================
-- Ce script génère des millions de lignes de données simulant les transactions
-- de la Petite Souris sur plusieurs années.
--
-- Par défaut: ~50M de lignes sur 5 ans (~1.5s entre chaque dent)
-- Temps d'exécution: 2-3 minutes selon votre machine
--
-- Usage: psql -h localhost -U postgres -d postgres -f scripts/02-generate-data.sql
-- ============================================================================

\echo '🦷 === Génération de données pour la Petite Souris ==='
\echo ''

-- Configuration
\echo '⚙️  Configuration:'
\echo '   - Période: 5 ans (NOW() - INTERVAL ''5 years'' à NOW())'
\echo '   - Intervalle: 1.5 secondes entre chaque dent'
\echo '   - Volume estimé: ~100 millions de lignes'
\echo '   - Espace disque: ~8-10 GB (avant compression)'
\echo ''
\echo '⏱️  Démarrage de la génération... (cela peut prendre 2-3 minutes)'
\echo ''

-- Désactiver temporairement les notices pour accélérer l'insertion
SET client_min_messages TO WARNING;

-- Insertion massive avec generate_series
INSERT INTO tooth_loss (
    time,
    child_id,
    tooth_number,
    country,
    city,
    price,
    payment_method
)
SELECT
    time,
    -- ID d'enfant aléatoire (2 milliards d'enfants dans le monde)
    (random() * 2000000000)::int as child_id,

    -- Numéro de dent (1-20 pour les dents de lait)
    (random() * 20 + 1)::int as tooth_number,

    -- Pays (distribution réaliste)
    (ARRAY['FR', 'FR', 'DE', 'ES', 'IT', 'US', 'US', 'UK', 'CA', 'AU',
           'JP', 'CN', 'IN', 'BR', 'MX', 'AR', 'PT', 'BE', 'NL', 'SE'])[ceil(random()*20)] as country,

    -- Ville
    'City_' || (random() * 10000)::int as city,

    -- Prix (entre 0.50€ et 10.50€, avec inflation au fil du temps)
    ROUND(
        (random() * 10 + 0.5 +
         -- Inflation de 2% par an
         EXTRACT(YEAR FROM AGE(NOW(), time)) * 0.2
        )::numeric,
        2
    ) as price,

    -- Méthode de paiement (70% cash, 20% coin, 10% gift)
    CASE
        WHEN random() < 0.7 THEN 'cash'
        WHEN random() < 0.9 THEN 'coin'
        ELSE 'gift'
    END as payment_method

FROM generate_series(
    NOW() - INTERVAL '5 years',
    NOW(),
    INTERVAL '1.5 seconds'  -- Pour avoir ~100M lignes
) AS time;

-- Réactiver les notices
RESET client_min_messages;

\echo ''
\echo '✅ Données générées avec succès !'
\echo ''

-- Statistiques
\echo '📊 Statistiques:'
SELECT
    COUNT(*) as total_rows,
    pg_size_pretty(pg_total_relation_size('tooth_loss')) as table_size,
    MIN(time) as oldest_record,
    MAX(time) as newest_record,
    COUNT(DISTINCT country) as countries,
    COUNT(DISTINCT city) as cities
FROM tooth_loss;

\echo ''
\echo '📦 Chunks créés:'
SELECT
    chunk_name,
    range_start::date as start_date,
    range_end::date as end_date,
    pg_size_pretty(
        pg_total_relation_size(format('%I.%I', chunk_schema, chunk_name))
    ) as size
FROM timescaledb_information.chunks
WHERE hypertable_name = 'tooth_loss'
ORDER BY range_start DESC
LIMIT 10;

\echo ''
\echo '🎉 Génération terminée ! Vous pouvez maintenant tester les requêtes avec 03-queries.sql'
\echo ''

-- ============================================================================
-- AJUSTEMENT DU VOLUME DE DONNÉES
-- ============================================================================
-- Si vous voulez plus ou moins de données, modifiez l'intervalle:
--
-- Pour ~10M de lignes (~1.5 ans):
-- FROM generate_series(
--     NOW() - INTERVAL '1.5 years',
--     NOW(),
--     INTERVAL '5 seconds'
-- ) AS time;
--
-- Pour ~50M de lignes (~2.5 ans):
-- FROM generate_series(
--     NOW() - INTERVAL '2.5 years',
--     NOW(),
--     INTERVAL '1.5 seconds'
-- ) AS time;
--
-- Pour ~200M de lignes (~10 ans):
-- FROM generate_series(
--     NOW() - INTERVAL '10 years',
--     NOW(),
--     INTERVAL '1.5 seconds'
-- ) AS time;
-- ============================================================================
