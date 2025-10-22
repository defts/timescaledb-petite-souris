-- ============================================================================
-- Script 03: Requêtes temporelles avec time_bucket
-- ============================================================================
-- Démonstration de time_bucket pour l'agrégation temporelle
--
-- Cette requête sera optimisée avec un continuous aggregate dans le script 06
--
-- Usage: psql -h localhost -U postgres -d petite_souris -f scripts/03-queries.sql
-- ============================================================================

\echo '🦷 === Requêtes temporelles avec TimescaleDB ==='
\echo ''

-- ============================================================================
-- Stats par minute (dernière heure)
-- ============================================================================
\echo '📊 === Stats par minute (temps réel) ==='
\echo ''

SELECT
    time_bucket('1 minute', collected_at) AS minute,
    country_code,
    COUNT(*) as teeth_count,
    ROUND(AVG(price)::numeric, 2) as avg_price,
    ROUND(SUM(price)::numeric, 2) as total_revenue
FROM tooth_loss
WHERE collected_at > NOW() - INTERVAL '1 hour'
GROUP BY minute, country_code
ORDER BY minute DESC, country_code
LIMIT 20;

\echo ''
\echo '⚠️  Cette requête recalcule tout à chaque exécution'
\echo '💡 Solution : Continuous Aggregates (script 06) pour pré-calculer et auto-rafraîchir'
\echo ''
