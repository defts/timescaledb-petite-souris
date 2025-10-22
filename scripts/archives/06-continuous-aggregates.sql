-- ============================================================================
-- Script 06: Continuous Aggregates (Agrégats continus)
-- ============================================================================
-- Ce script démontre comment optimiser la requête du script 03 avec
-- un continuous aggregate qui se met à jour automatiquement.
--
-- Usage: psql -h localhost -U postgres -d petite_souris -f scripts/06-continuous-aggregates.sql
-- ============================================================================

\echo '🦷 === Continuous Aggregates avec TimescaleDB ==='
\echo ''

-- ============================================================================
-- Étape 1: Rappel de la requête du script 03
-- ============================================================================
\echo '📊 === Étape 1: Rappel de la requête du script 03 ==='
\echo ''
\echo 'Requête qui recalcule tout à chaque exécution:'
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
\echo '⚠️  On va maintenant matérialiser cette requête...'
\echo ''

-- ============================================================================
-- Étape 2: Créer le continuous aggregate
-- ============================================================================
\echo '🏗️  === Étape 2: Création du continuous aggregate ==='
\echo ''
\echo 'On transforme la requête en vue matérialisée continue...'
\echo ''

-- Créer une vue matérialisée continue avec real-time aggregation
-- materialized_only = false permet de combiner données matérialisées + récentes
CREATE MATERIALIZED VIEW IF NOT EXISTS minute_stats
WITH (timescaledb.continuous, timescaledb.materialized_only = false) AS
SELECT
    time_bucket('1 minute', collected_at) AS minute,
    country_code,
    COUNT(*) as teeth_count,
    AVG(price) as avg_price,
    SUM(price) as total_revenue
FROM tooth_loss
GROUP BY minute, country_code;

\echo '✅ Continuous aggregate ''minute_stats'' créé'
\echo '   → Real-time aggregation activé (materialized_only = false)'
\echo ''

-- ============================================================================
-- Étape 3: Rafraîchir le continuous aggregate
-- ============================================================================
\echo '🔄 === Étape 3: Rafraîchissement initial ==='
\echo ''
\echo '⏱️  Rafraîchissement en cours...'
\echo ''

-- Rafraîchir toutes les données
CALL refresh_continuous_aggregate('minute_stats', NULL, NULL);

\echo '✅ Continuous aggregate rafraîchi'
\echo ''

-- ============================================================================
-- Étape 4: Utiliser le continuous aggregate
-- ============================================================================
\echo '⚡ === Étape 4: Utilisation du continuous aggregate ==='
\echo ''
\echo 'Requête simple : Prix moyen global par minute'
\echo ''

SELECT
    minute,
    SUM(teeth_count) as total_teeth,
    ROUND((SUM(total_revenue) / SUM(teeth_count))::numeric, 2) as avg_price
FROM minute_stats
WHERE minute > NOW() - INTERVAL '1 hour'
GROUP BY minute
ORDER BY minute DESC
LIMIT 20;

\echo ''
\echo '🚀 Les données sont déjà agrégées → lecture instantanée !'
\echo ''

-- ============================================================================
-- Étape 5: Configurer le rafraîchissement automatique
-- ============================================================================
\echo '🤖 === Étape 5: Configuration du rafraîchissement automatique ==='
\echo ''

-- Configurer le rafraîchissement automatique
-- - start_offset: commence à rafraîchir à partir d'il y a 1 heure
-- - end_offset: s'arrête 10 secondes avant maintenant (les données plus récentes sont agrégées en temps réel)
-- - schedule_interval: exécute toutes les 10 secondes pour une démo fluide
SELECT add_continuous_aggregate_policy('minute_stats',
    start_offset => INTERVAL '1 hour',
    end_offset => INTERVAL '10 seconds',
    schedule_interval => INTERVAL '10 seconds'
);

\echo '✅ Policy de rafraîchissement créée !'
\echo '   - Exécution: toutes les 10 secondes'
\echo '   - Fenêtre matérialisée: de -1 heure à -10 secondes'
\echo '   - Données < 10 secondes: agrégées en temps réel (real-time aggregation)'
\echo ''

-- ============================================================================
-- Étape 6: Vérification du real-time aggregation
-- ============================================================================
\echo '📋 === Étape 6: Vérification du mode real-time ==='
\echo ''

SELECT
    view_name,
    materialized_only,
    CASE
        WHEN materialized_only THEN '❌ Seulement données matérialisées'
        ELSE '✅ Real-time aggregation activé'
    END as mode
FROM timescaledb_information.continuous_aggregates
WHERE view_name = 'minute_stats';

\echo ''

-- ============================================================================
-- Étape 7: Continuous Aggregates + stats_agg() (Hyperfunctions)
-- ============================================================================
\echo '💎 === Étape 7: Combiner Continuous Aggregates + Hyperfunctions ==='
\echo ''
\echo 'Créer un cagg avec stats_agg() pour extraire plusieurs stats sans recalculer...'
\echo ''

-- Créer une vue matérialisée avec stats_agg
CREATE MATERIALIZED VIEW IF NOT EXISTS daily_stats_advanced
WITH (timescaledb.continuous, timescaledb.materialized_only = false) AS
SELECT
    time_bucket('1 day', collected_at) AS day,
    country_code,
    stats_agg(price) as price_stats  -- Calculé UNE FOIS, matérialisé
FROM tooth_loss
GROUP BY day, country_code;

\echo '✅ Continuous aggregate ''daily_stats_advanced'' créé avec stats_agg()'
\echo ''

-- Rafraîchir
\echo '🔄 Rafraîchissement initial...'
CALL refresh_continuous_aggregate('daily_stats_advanced', NULL, NULL);

\echo '✅ Rafraîchi'
\echo ''

-- ============================================================================
-- Étape 8: Extraire plusieurs statistiques depuis le cagg
-- ============================================================================
\echo '⚡ === Étape 8: Extraire plusieurs stats = GRATUIT ! ==='
\echo ''
\echo 'Le stats_agg est matérialisé, les accesseurs sont quasi-gratuits:'
\echo ''

SELECT
    day,
    country_code,
    price_stats -> average() as avg_price,
    price_stats -> stddev() as stddev_price,
    price_stats -> variance() as variance_price,
    price_stats -> sum() as total_revenue,
    price_stats -> num_vals() as nb_transactions
FROM daily_stats_advanced
WHERE day > NOW() - INTERVAL '30 days'
ORDER BY day DESC, country_code
LIMIT 20;

\echo ''
\echo '💡 5 statistiques extraites sans recalcul !'
\echo '💡 Le stats_agg est déjà pré-calculé et matérialisé'
\echo ''

-- Comparer avec une requête qui recalculerait tout
\echo '📊 Comparaison: Recalculer vs Extraire depuis cagg'
\echo ''

\echo '--- Temps pour recalculer (scan la hypertable) ---'
EXPLAIN ANALYZE
SELECT
    time_bucket('1 day', collected_at) AS day,
    country_code,
    AVG(price) as avg_price,
    STDDEV(price) as stddev_price,
    VARIANCE(price) as variance_price,
    SUM(price) as total_revenue,
    COUNT(*) as nb_transactions
FROM tooth_loss
WHERE collected_at > NOW() - INTERVAL '30 days'
GROUP BY day, country_code
ORDER BY day DESC, country_code
LIMIT 20;

\echo ''
\echo '--- Temps pour extraire depuis cagg (lecture de la vue) ---'
EXPLAIN ANALYZE
SELECT
    day,
    country_code,
    price_stats -> average() as avg_price,
    price_stats -> stddev() as stddev_price,
    price_stats -> variance() as variance_price,
    price_stats -> sum() as total_revenue,
    price_stats -> num_vals() as nb_transactions
FROM daily_stats_advanced
WHERE day > NOW() - INTERVAL '30 days'
ORDER BY day DESC, country_code
LIMIT 20;

\echo ''
\echo '🚀 Avec le cagg + stats_agg:'
\echo '   • 10-100x plus rapide (lecture de la vue pré-calculée)'
\echo '   • Extraction de N stats = gratuit (accesseurs sur stats_agg)'
\echo '   • Rafraîchissement incrémental automatique'
\echo ''

-- ============================================================================
-- Résumé
-- ============================================================================
\echo ''
\echo '🎉 Démonstration des continuous aggregates terminée !'
\echo ''
\echo '📊 Points clés:'
\echo '   ✅ Même requête que le script 03, mais pré-calculée'
\echo '   ✅ 10-100x plus rapide en lecture'
\echo '   ✅ Rafraîchissement automatique et incrémental'
\echo '   ✅ Real-time aggregation: combine données matérialisées + nouvelles données'
\echo '   ✅ Transparent pour les applications (c'\''est une vue SQL)'
\echo ''
\echo '💎 Bonus avec stats_agg():'
\echo '   ✅ Calculer stats_agg() UNE FOIS dans le cagg'
\echo '   ✅ Extraire N statistiques sans recalcul (average, stddev, variance...)'
\echo '   ✅ Parfait pour dashboards avec multiples métriques'
\echo ''
\echo '🔥 Real-time aggregation expliqué:'
\echo '   • Données > 10 sec: pré-agrégées (matérialisées) → ultra rapide'
\echo '   • Données < 10 sec: agrégées à la volée → toujours à jour'
\echo '   • Résultat: Le meilleur des deux mondes !'
\echo ''
\echo '💡 Démo en live:'
\echo '   1. Lancez "make stream" dans un autre terminal'
\echo '   2. Re-requêtez minute_stats toutes les quelques secondes'
\echo '   3. Les nouvelles données apparaissent INSTANTANÉMENT !'
\echo ''
\echo '💡 Commandes utiles:'
\echo '   -- Rafraîchir manuellement:'
\echo '   CALL refresh_continuous_aggregate(''minute_stats'', NULL, NULL);'
\echo ''
\echo '   -- Supprimer la policy:'
\echo '   SELECT remove_continuous_aggregate_policy(''minute_stats'');'
\echo ''
\echo '   -- Supprimer le continuous aggregate:'
\echo '   DROP MATERIALIZED VIEW minute_stats;'
\echo '   DROP MATERIALIZED VIEW daily_stats_advanced;'
\echo ''
