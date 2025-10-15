-- ============================================================================
-- Script 06: Continuous Aggregates (Agrégats continus)
-- ============================================================================
-- Ce script démontre comment créer des vues matérialisées continues
-- qui se mettent à jour automatiquement pour accélérer les requêtes.
--
-- Usage: psql -h localhost -U postgres -d postgres -f scripts/06-continuous-aggregates.sql
-- ============================================================================

\echo '🦷 === Continuous Aggregates avec TimescaleDB ==='
\echo ''

-- ============================================================================
-- Étape 1: Benchmark d'une requête lente (sans continuous aggregate)
-- ============================================================================
\echo '📊 === Benchmark: Requête SANS continuous aggregate ==='
\echo ''
\timing on

EXPLAIN ANALYZE
SELECT
    time_bucket('1 day', time) AS day,
    country,
    COUNT(*) as teeth_count,
    ROUND(AVG(price)::numeric, 2) as avg_price,
    ROUND(MIN(price)::numeric, 2) as min_price,
    ROUND(MAX(price)::numeric, 2) as max_price,
    ROUND(SUM(price)::numeric, 2) as total_revenue
FROM tooth_loss
WHERE time > NOW() - INTERVAL '6 months'
GROUP BY day, country
ORDER BY day DESC, country
LIMIT 100;

\timing off
\echo ''

-- ============================================================================
-- Étape 2: Créer un continuous aggregate pour les stats journalières
-- ============================================================================
\echo '🏗️  === Création du continuous aggregate ==='
\echo ''

-- Créer une vue matérialisée continue pour les statistiques journalières
CREATE MATERIALIZED VIEW IF NOT EXISTS daily_stats
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 day', time) AS day,
    country,
    COUNT(*) as teeth_count,
    AVG(price) as avg_price,
    MIN(price) as min_price,
    MAX(price) as max_price,
    SUM(price) as total_revenue,
    -- Stats additionnelles utiles
    COUNT(DISTINCT child_id) as unique_children,
    COUNT(DISTINCT city) as cities_count
FROM tooth_loss
GROUP BY day, country
WITH NO DATA;

\echo '✅ Continuous aggregate ''daily_stats'' créé'
\echo ''

-- ============================================================================
-- Étape 3: Rafraîchir le continuous aggregate
-- ============================================================================
\echo '🔄 === Rafraîchissement initial du continuous aggregate ==='
\echo ''
\echo '⏱️  Rafraîchissement en cours... (peut prendre 30-60 secondes)'
\echo ''

-- Rafraîchir toutes les données
CALL refresh_continuous_aggregate('daily_stats', NULL, NULL);

\echo '✅ Continuous aggregate rafraîchi'
\echo ''

-- Vérifier les données
\echo '📊 Aperçu des données dans le continuous aggregate:'
SELECT * FROM daily_stats
ORDER BY day DESC, country
LIMIT 10;

-- ============================================================================
-- Étape 4: Benchmark avec le continuous aggregate
-- ============================================================================
\echo ''
\echo '📊 === Benchmark: Requête AVEC continuous aggregate ==='
\echo ''
\timing on

EXPLAIN ANALYZE
SELECT
    day,
    country,
    teeth_count,
    ROUND(avg_price::numeric, 2) as avg_price,
    ROUND(min_price::numeric, 2) as min_price,
    ROUND(max_price::numeric, 2) as max_price,
    ROUND(total_revenue::numeric, 2) as total_revenue
FROM daily_stats
WHERE day > NOW() - INTERVAL '6 months'
ORDER BY day DESC, country
LIMIT 100;

\timing off
\echo ''
\echo '💡 Comparez le temps d''exécution ! 🚀'
\echo ''

-- ============================================================================
-- Étape 5: Créer une refresh policy automatique
-- ============================================================================
\echo '🤖 === Configuration du rafraîchissement automatique ==='
\echo ''

-- Configurer le rafraîchissement automatique
-- - start_offset: commence à rafraîchir à partir d'il y a 1 mois
-- - end_offset: s'arrête 1 heure avant maintenant (données récentes)
-- - schedule_interval: exécute toutes les heures
SELECT add_continuous_aggregate_policy('daily_stats',
    start_offset => INTERVAL '1 month',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour'
);

\echo '✅ Policy de rafraîchissement créée !'
\echo '   - Exécution: toutes les heures'
\echo '   - Fenêtre: de -1 mois à -1 heure'
\echo ''

-- ============================================================================
-- Étape 6: Créer d'autres continuous aggregates utiles
-- ============================================================================
\echo '🏗️  === Création d''autres continuous aggregates ==='
\echo ''

-- Continuous aggregate pour les stats horaires (plus granulaire)
\echo '1️⃣  Stats horaires...'
CREATE MATERIALIZED VIEW IF NOT EXISTS hourly_stats
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 hour', time) AS hour,
    country,
    COUNT(*) as teeth_count,
    AVG(price) as avg_price,
    SUM(price) as total_revenue
FROM tooth_loss
GROUP BY hour, country
WITH NO DATA;

-- Continuous aggregate pour les stats mensuelles par ville
\echo '2️⃣  Stats mensuelles par ville...'
CREATE MATERIALIZED VIEW IF NOT EXISTS monthly_city_stats
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 month', time) AS month,
    country,
    city,
    COUNT(*) as teeth_count,
    AVG(price) as avg_price,
    MIN(price) as min_price,
    MAX(price) as max_price,
    SUM(price) as total_revenue
FROM tooth_loss
GROUP BY month, country, city
WITH NO DATA;

-- Continuous aggregate pour les stats par méthode de paiement
\echo '3️⃣  Stats par méthode de paiement...'
CREATE MATERIALIZED VIEW IF NOT EXISTS payment_method_stats
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 day', time) AS day,
    payment_method,
    COUNT(*) as transaction_count,
    AVG(price) as avg_price,
    SUM(price) as total_revenue
FROM tooth_loss
GROUP BY day, payment_method
WITH NO DATA;

\echo '✅ Tous les continuous aggregates créés'
\echo ''

-- Rafraîchir tous les nouveaux aggregates
\echo '🔄 Rafraîchissement des nouveaux aggregates...'
CALL refresh_continuous_aggregate('hourly_stats', NULL, NULL);
CALL refresh_continuous_aggregate('monthly_city_stats', NULL, NULL);
CALL refresh_continuous_aggregate('payment_method_stats', NULL, NULL);

\echo '✅ Tous les aggregates rafraîchis'
\echo ''

-- ============================================================================
-- Étape 7: Exemples de requêtes utilisant les continuous aggregates
-- ============================================================================
\echo '📊 === Exemples de requêtes rapides ==='
\echo ''

\echo '1️⃣  Top 5 pays par revenus (derniers 3 mois):'
SELECT
    country,
    SUM(teeth_count) as total_teeth,
    pg_size_pretty(SUM(total_revenue)::bigint) as total_revenue_formatted,
    ROUND(AVG(avg_price)::numeric, 2) as overall_avg_price
FROM daily_stats
WHERE day > NOW() - INTERVAL '3 months'
GROUP BY country
ORDER BY SUM(total_revenue) DESC
LIMIT 5;

\echo ''
\echo '2️⃣  Évolution du prix moyen par semaine:'
SELECT
    time_bucket('1 week', day) AS week,
    ROUND(AVG(avg_price)::numeric, 2) as weekly_avg_price,
    SUM(teeth_count) as weekly_teeth
FROM daily_stats
WHERE day > NOW() - INTERVAL '6 months'
GROUP BY week
ORDER BY week DESC
LIMIT 10;

\echo ''
\echo '3️⃣  Heures de pointe (dernière semaine):'
SELECT
    EXTRACT(HOUR FROM hour) as hour_of_day,
    SUM(teeth_count) as total_teeth,
    ROUND(AVG(avg_price)::numeric, 2) as avg_price
FROM hourly_stats
WHERE hour > NOW() - INTERVAL '1 week'
GROUP BY hour_of_day
ORDER BY total_teeth DESC
LIMIT 5;

\echo ''
\echo '4️⃣  Méthodes de paiement les plus populaires (dernier mois):'
SELECT
    payment_method,
    SUM(transaction_count) as total_transactions,
    ROUND(AVG(avg_price)::numeric, 2) as avg_price,
    ROUND(
        (SUM(transaction_count) * 100.0 /
         (SELECT SUM(transaction_count) FROM payment_method_stats WHERE day > NOW() - INTERVAL '1 month'))::numeric,
        1
    ) as percentage
FROM payment_method_stats
WHERE day > NOW() - INTERVAL '1 month'
GROUP BY payment_method
ORDER BY total_transactions DESC;

-- ============================================================================
-- Étape 8: Monitoring des continuous aggregates
-- ============================================================================
\echo ''
\echo '📋 === Monitoring des continuous aggregates ==='
\echo ''

\echo 'Liste des continuous aggregates:'
SELECT
    view_name,
    materialized_only,
    compression_enabled
FROM timescaledb_information.continuous_aggregates
ORDER BY view_name;

\echo ''
\echo 'Jobs de rafraîchissement configurés:'
SELECT
    ca.view_name,
    j.schedule_interval,
    j.next_start,
    j.last_run_status,
    j.last_successful_finish
FROM timescaledb_information.continuous_aggregates ca
JOIN timescaledb_information.jobs j ON j.hypertable_name = ca.materialization_hypertable_name
WHERE j.proc_name = 'policy_refresh_continuous_aggregate'
ORDER BY ca.view_name;

\echo ''
\echo 'Taille des continuous aggregates:'
SELECT
    view_name,
    pg_size_pretty(pg_total_relation_size(format('%I.%I', view_schema, view_name))) as size
FROM timescaledb_information.continuous_aggregates
ORDER BY pg_total_relation_size(format('%I.%I', view_schema, view_name)) DESC;

-- ============================================================================
-- Étape 9: Compression des continuous aggregates
-- ============================================================================
\echo ''
\echo '🗜️  === Activer la compression sur les continuous aggregates ==='
\echo ''

-- On peut aussi compresser les continuous aggregates !
ALTER MATERIALIZED VIEW daily_stats SET (
    timescaledb.compress = true
);

SELECT add_compression_policy('daily_stats', INTERVAL '7 days');

\echo '✅ Compression activée sur daily_stats'
\echo ''

-- ============================================================================
-- Gestion des continuous aggregates
-- ============================================================================
\echo '🔧 === Gestion des continuous aggregates ==='
\echo ''
\echo '💡 Commandes utiles:'
\echo ''
\echo '-- Rafraîchir manuellement:'
\echo '   CALL refresh_continuous_aggregate(''daily_stats'', NULL, NULL);'
\echo ''
\echo '-- Rafraîchir une période spécifique:'
\echo '   CALL refresh_continuous_aggregate(''daily_stats'', ''2024-01-01'', ''2024-02-01'');'
\echo ''
\echo '-- Supprimer une policy de rafraîchissement:'
\echo '   SELECT remove_continuous_aggregate_policy(''daily_stats'');'
\echo ''
\echo '-- Supprimer un continuous aggregate:'
\echo '   DROP MATERIALIZED VIEW daily_stats;'
\echo ''
\echo '-- Voir les logs d''un job:'
\echo '   SELECT * FROM timescaledb_information.job_stats WHERE job_id = <job_id>;'
\echo ''

\echo ''
\echo '🎉 Démonstration des continuous aggregates terminée !'
\echo ''
\echo '📊 Points clés à retenir:'
\echo '   ✅ Vues matérialisées qui se mettent à jour automatiquement'
\echo '   ✅ Performances 10-100x meilleures sur requêtes agrégées'
\echo '   ✅ Rafraîchissement incrémental (seulement nouvelles données)'
\echo '   ✅ Combinable avec compression pour économiser l''espace'
\echo '   ✅ Transparent pour les applications (ce sont des vues SQL)'
\echo '   ✅ Multiples niveaux d''agrégation possibles (hour/day/month)'
\echo ''

-- ============================================================================
-- NOTES POUR LA PRÉSENTATION
-- ============================================================================
-- 1. Montrer d'abord la requête lente (EXPLAIN ANALYZE)
-- 2. Créer le continuous aggregate en direct
-- 3. Rafraîchir et montrer la différence de performance
-- 4. Expliquer le rafraîchissement incrémental
-- 5. Montrer les policies automatiques
-- 6. Mentionner la possibilité de cascader (aggregates d'aggregates)
-- 7. Insister sur le fait que c'est du SQL standard
-- 8. Real-time aggregation: données récentes + aggregate
-- ============================================================================
