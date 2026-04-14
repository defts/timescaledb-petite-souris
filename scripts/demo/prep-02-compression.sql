-- ============================================================================
-- PRÉPARATION COMPRESSION : À exécuter AVANT la présentation
-- ============================================================================
-- Ce script active la compression et compresse les données anciennes.
-- Durée estimée : 1-2 minutes
--
-- Usage: psql -h localhost -U postgres -d petite_souris -f scripts/demo/prep-02-compression.sql
-- ============================================================================

\echo '🗜️  === Préparation de la compression ==='
\echo ''

-- Activer la compression avec stratégie par pays
\echo '1️⃣  Activation de la compression...'
ALTER TABLE tooth_loss SET (
    timescaledb.enable_columnstore,
    timescaledb.segmentby = 'country_code'
);

\echo '✅ Compression activée'
\echo ''

-- Créer une policy : compresser automatiquement les données > 7 jours
\echo '2️⃣  Création de la policy de compression automatique...'
SELECT add_columnstore_policy('tooth_loss', INTERVAL '7 days');

\echo '✅ Policy créée (compression auto des données > 7 jours)'
\echo ''

-- Compresser manuellement toutes les données > 7 jours
\echo '3️⃣  Compression manuelle des chunks anciens (peut prendre 1-2 min)...'
\echo ''

SELECT convert_to_columnstore(i, if_not_columnstore => true)
FROM show_chunks('tooth_loss', older_than => INTERVAL '7 days') i;

\echo ''
\echo '✅ Chunks anciens compressés'
\echo ''

-- Afficher les stats finales
\echo '📊 === Stats finales ==='
\echo ''

SELECT
    pg_size_pretty(before_compression_total_bytes) as taille_avant,
    pg_size_pretty(after_compression_total_bytes) as taille_apres,
    ROUND((1 - after_compression_total_bytes::float / before_compression_total_bytes) * 100, 1) as gain_pourcent,
    number_compressed_chunks as chunks_compresses,
    (total_chunks - number_compressed_chunks) as chunks_non_compresses
FROM hypertable_columnstore_stats('tooth_loss');

\echo ''
\echo '🎉 Préparation terminée !'
\echo '💡 Vous pouvez maintenant lancer la démo : scripts/demo/02-compression.sql'
\echo ''
