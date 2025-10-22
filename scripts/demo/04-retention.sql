SELECT
    MIN(collected_at) as premiere_dent,
    MAX(collected_at) as derniere_dent,
    AGE(MAX(collected_at), MIN(collected_at)) as periode_totale,
    COUNT(*) as total_dents
FROM tooth_loss;

SELECT
    chunk_name,
    range_start,
    range_end,
    CASE
        WHEN range_end < NOW() - INTERVAL '6 months'
        THEN 'Serait supprimé'
        ELSE 'Conservé'
    END as statut_si_policy_6mois
FROM timescaledb_information.chunks
WHERE hypertable_name = 'tooth_loss'
ORDER BY range_start DESC;
