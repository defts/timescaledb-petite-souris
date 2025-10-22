-- ============================================================================
-- PRÉPARATION : Continuous Aggregates
-- ============================================================================
-- Ce script doit être exécuté AVANT la présentation pour :
-- 1. Créer la continuous aggregate avec stats_agg + percentile_agg
-- 2. Créer la refresh policy pour auto-refresh
--
-- Exécution :
-- psql -h localhost -U postgres -d petite_souris -f scripts/demo/prep-03-caggs.sql
-- ============================================================================

\echo '🔧 Préparation : Création de la continuous aggregate'
\echo ''

-- Supprimer si elle existe déjà (CASCADE supprime aussi la policy)
DROP MATERIALIZED VIEW IF EXISTS daily_revenue_stats CASCADE;

\echo '🗑️  Ancienne vue supprimée (si existante)'
\echo ''

-- Créer la continuous aggregate avec real-time aggregation
CREATE MATERIALIZED VIEW daily_revenue_stats
WITH (timescaledb.continuous, timescaledb.materialized_only = false) AS
SELECT
    time_bucket('1 day', collected_at) as day,
    country_code,
    stats_agg(price) as price_stats,
    percentile_agg(price) as price_percentiles
FROM tooth_loss
GROUP BY day, country_code;

\echo '✅ Continuous aggregate créée'
\echo ''

-- Ajouter une refresh policy
-- start_offset: matérialiser depuis -1 mois
-- end_offset: matérialiser jusqu'à -1 heure (laisse les données récentes en real-time)
SELECT add_continuous_aggregate_policy('daily_revenue_stats',
    start_offset => INTERVAL '1 month',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour');

\echo '✅ Refresh policy créée'
\echo ''

-- Rafraîchir manuellement pour avoir les données déjà matérialisées
CALL refresh_continuous_aggregate('daily_revenue_stats', NULL, NOW() - INTERVAL '1 hour');

\echo '✅ Données matérialisées'
\echo ''
\echo '🎉 Préparation terminée ! La continuous aggregate est prête pour la démo.'
\echo '💡 Les données > 1 heure sont matérialisées, les données < 1 heure sont en real-time'
\echo ''
