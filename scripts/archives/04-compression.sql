-- ============================================================================
-- Script 04: Compression des données
-- ============================================================================
-- Ce script démontre les capacités de compression de TimescaleDB.
-- La compression peut réduire la taille des données de 90% ou plus.
--
-- Usage: psql -h localhost -U postgres -d postgres -f scripts/04-compression.sql
-- ============================================================================

\echo '🦷 === Compression TimescaleDB ==='
\echo ''

-- ============================================================================
-- Étape 1: État avant compression
-- ============================================================================
\echo '📊 === État AVANT compression ==='
\echo ''

SELECT
    pg_size_pretty(hypertable_size('tooth_loss')) as total_size,
    pg_size_pretty(hypertable_size('tooth_loss') - hypertable_index_size('tooth_loss')) as table_size,
    pg_size_pretty(hypertable_index_size('tooth_loss')) as index_size
FROM timescaledb_information.hypertables
WHERE hypertable_name = 'tooth_loss';

\echo ''
\echo '📦 Nombre de chunks:'
SELECT COUNT(*) as total_chunks
FROM timescaledb_information.chunks
WHERE hypertable_name = 'tooth_loss';

\echo ''
\echo '📦 Détail des 5 plus gros chunks (non compressés):'
SELECT
    chunk_name,
    range_start::date as start_date,
    range_end::date as end_date,
    pg_size_pretty(
        pg_total_relation_size(format('%I.%I', chunk_schema, chunk_name))
    ) as size,
    CASE WHEN is_compressed THEN 'Compressed' ELSE 'Uncompressed' END as status
FROM timescaledb_information.chunks
WHERE hypertable_name = 'tooth_loss'
ORDER BY pg_total_relation_size(format('%I.%I', chunk_schema, chunk_name)) DESC
LIMIT 5;

-- ============================================================================
-- Étape 2: Activer la compression sur la hypertable
-- ============================================================================
\echo ''
\echo '⚙️  === Configuration de la compression ==='
\echo ''

-- Configurer la compression
-- segmentby: regrouper par country (données du même pays ensemble)
-- orderby: trier par time DESC dans chaque segment
ALTER TABLE tooth_loss SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'country',
    timescaledb.compress_orderby = 'time DESC'
);

\echo '✅ Compression activée avec:'
\echo '   - segment_by: country'
\echo '   - order_by: time DESC'
\echo ''

-- ============================================================================
-- Étape 3: Compresser manuellement les chunks anciens (> 7 jours)
-- ============================================================================
\echo '🗜️  === Compression manuelle des chunks > 7 jours ==='
\echo ''

-- Afficher combien de chunks seront compressés
SELECT COUNT(*) as chunks_to_compress
FROM timescaledb_information.chunks
WHERE hypertable_name = 'tooth_loss'
  AND range_end < NOW() - INTERVAL '7 days'
  AND NOT is_compressed;

\echo ''
\echo '⏱️  Compression en cours... (cela peut prendre 1-2 minutes)'
\echo ''

-- Compresser tous les chunks > 7 jours
SELECT compress_chunk(format('%I.%I', chunk_schema, chunk_name)::regclass, if_not_compressed => true)
FROM timescaledb_information.chunks
WHERE hypertable_name = 'tooth_loss'
  AND range_end < NOW() - INTERVAL '7 days'
  AND NOT is_compressed;

-- ============================================================================
-- Étape 4: Résultats de la compression
-- ============================================================================
\echo ''
\echo '📊 === État APRÈS compression ==='
\echo ''

SELECT
    pg_size_pretty(hypertable_size('tooth_loss')) as total_size,
    pg_size_pretty(hypertable_size('tooth_loss') - hypertable_index_size('tooth_loss')) as table_size,
    pg_size_pretty(hypertable_index_size('tooth_loss')) as index_size
FROM timescaledb_information.hypertables
WHERE hypertable_name = 'tooth_loss';

\echo ''
\echo '📦 Statistiques de compression globales:'
SELECT
    total_chunks,
    number_compressed_chunks as compressed,
    total_chunks - number_compressed_chunks as uncompressed,
    pg_size_pretty(before_compression_total_bytes) as size_before_compression,
    pg_size_pretty(after_compression_total_bytes) as size_after_compression,
    pg_size_pretty(before_compression_total_bytes - after_compression_total_bytes) as space_saved,
    ROUND(
        (100 - (after_compression_total_bytes::float /
               NULLIF(before_compression_total_bytes, 0)::float * 100))::numeric,
        1
    ) as compression_ratio_percent
FROM hypertable_compression_stats('tooth_loss');

\echo ''
\echo '📦 Statistiques par chunk (top 10 chunks compressés):'
SELECT
    chunk_schema || '.' || chunk_name as chunk,
    compression_status,
    pg_size_pretty(before_compression_total_bytes) as before,
    pg_size_pretty(after_compression_total_bytes) as after,
    ROUND(
        (100 - (after_compression_total_bytes::float /
               NULLIF(before_compression_total_bytes, 0)::float * 100))::numeric,
        1
    ) as compression_ratio_percent
FROM chunk_compression_stats('tooth_loss')
WHERE compression_status = 'Compressed'
ORDER BY before_compression_total_bytes DESC
LIMIT 10;

-- ============================================================================
-- Étape 5: Tester les performances sur données compressées
-- ============================================================================
\echo ''
\echo '⚡ === Test de performance sur données compressées ==='
\echo ''
\timing on

-- Requête sur données compressées (anciennes)
\echo '--- Requête sur données compressées (1 an il y a 2 ans) ---'
EXPLAIN ANALYZE
SELECT
    time_bucket('1 day', time) AS day,
    country,
    COUNT(*) as transactions,
    ROUND(AVG(price)::numeric, 2) as avg_price
FROM tooth_loss
WHERE time BETWEEN NOW() - INTERVAL '3 years' AND NOW() - INTERVAL '2 years'
GROUP BY day, country
ORDER BY day
LIMIT 100;

\echo ''
\echo '--- Requête sur données non compressées (7 derniers jours) ---'
EXPLAIN ANALYZE
SELECT
    time_bucket('1 day', time) AS day,
    country,
    COUNT(*) as transactions,
    ROUND(AVG(price)::numeric, 2) as avg_price
FROM tooth_loss
WHERE time > NOW() - INTERVAL '7 days'
GROUP BY day, country
ORDER BY day;

\timing off

-- ============================================================================
-- Étape 6: Configuration d'une policy de compression automatique
-- ============================================================================
\echo ''
\echo '🤖 === Configuration de la compression automatique ==='
\echo ''

-- Créer une policy pour compresser automatiquement les chunks > 7 jours
SELECT add_compression_policy('tooth_loss', INTERVAL '7 days');

\echo ''
\echo '✅ Policy de compression créée !'
\echo '   - Les chunks de plus de 7 jours seront automatiquement compressés'
\echo ''

-- Afficher toutes les policies actives
\echo '📋 Jobs de compression configurés:'
SELECT
    job_id,
    schedule_interval,
    config,
    next_start
FROM timescaledb_information.jobs
WHERE proc_name = 'policy_compression';

-- ============================================================================
-- Étape 7: Décompression (si nécessaire)
-- ============================================================================
\echo ''
\echo '💡 === Pour décompresser un chunk (si nécessaire) ==='
\echo ''
\echo '-- Exemple: SELECT decompress_chunk(''_timescaledb_internal._hyper_X_X_chunk'');'
\echo '-- Utile si vous devez modifier/supprimer des données anciennes'
\echo ''

\echo ''
\echo '🎉 Démonstration de compression terminée !'
\echo ''
\echo '📊 Points clés à retenir:'
\echo '   ✅ Compression activée avec segmentby et orderby'
\echo '   ✅ Chunks anciens compressés (ratio ~90%)'
\echo '   ✅ Policy automatique configurée'
\echo '   ✅ Performances maintenues en lecture'
\echo '   ✅ Gain d''espace disque massif'
\echo ''

-- ============================================================================
-- NOTES POUR LA PRÉSENTATION
-- ============================================================================
-- 1. Montrer l'état avant/après avec les tailles
-- 2. Expliquer le concept de segmentby (regroupement logique)
-- 3. Expliquer orderby (ordre optimal pour delta encoding)
-- 4. Montrer que les requêtes fonctionnent toujours
-- 5. Insister sur le ratio de compression (~90%)
-- 6. Mentionner que les données récentes restent non compressées (modifiables)
-- ============================================================================
