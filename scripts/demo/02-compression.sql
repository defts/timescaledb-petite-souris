-- -- Activer la compression avec stratégie par pays
-- ALTER TABLE tooth_loss SET (
--     timescaledb.enable_columnstore,
--     timescaledb.segmentby = 'country_code'
-- );
--
-- -- Créer une policy : compresser automatiquement les données > 7 jours
-- SELECT add_columnstore_policy('tooth_loss', INTERVAL '7 days');
--
-- ============================================================================

-- Stats de compression de toute la hypertable
SELECT
    pg_size_pretty(before_compression_total_bytes) as taille_avant,
    pg_size_pretty(after_compression_total_bytes) as taille_apres,
    ROUND((1 - after_compression_total_bytes::numeric / before_compression_total_bytes) * 100, 1) as gain_pourcent,
    number_compressed_chunks as chunks_compresses,
    (total_chunks - number_compressed_chunks) as chunks_non_compresses
FROM hypertable_columnstore_stats('tooth_loss');

-- details
SELECT
    c.chunk_name,
    c.range_start::date as debut,
    c.range_end::date as fin,
    pg_size_pretty(ccs.before_compression_total_bytes) as avant,
    pg_size_pretty(ccs.after_compression_total_bytes) as apres,
    ROUND((1 - ccs.after_compression_total_bytes::numeric / ccs.before_compression_total_bytes) * 100, 1) as gain_pct
FROM chunk_compression_stats('tooth_loss') ccs
JOIN timescaledb_information.chunks c
    ON c.chunk_schema = ccs.chunk_schema
    AND c.chunk_name = ccs.chunk_name
WHERE ccs.compression_status = 'Compressed'
ORDER BY ccs.before_compression_total_bytes DESC
LIMIT 10;

-- requete dans des données compressées
SELECT
    country_code,
    COUNT(*) as nb_dents,
    ROUND(AVG(price)::numeric, 2) as prix_moyen
FROM tooth_loss
WHERE collected_at >= '2024-10-01' AND collected_at < '2024-11-01'
GROUP BY country_code
ORDER BY nb_dents DESC
LIMIT 5;

--
SELECT
    application_name,
    schedule_interval,
    config::json->>'compress_after' as compress_after,
    next_start as prochaine_execution
FROM timescaledb_information.jobs
WHERE proc_name IN ('policy_compression', 'policy_columnstore');

