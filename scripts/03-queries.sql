-- ============================================================================
-- Script 03: Requêtes temporelles avec time_bucket
-- ============================================================================
-- Ce script contient les requêtes de démonstration pour la section 5
-- de la présentation: "Requêtes temporelles".
--
-- Il montre l'utilisation de time_bucket et les patterns courants
-- d'analyse de séries temporelles.
--
-- Usage: psql -h localhost -U postgres -d postgres -f scripts/03-queries.sql
-- ============================================================================

\echo '🦷 === Requêtes temporelles avec TimescaleDB ==='
\echo ''
\timing on

-- ============================================================================
-- Exemple 1: Prix moyen par mois (comparaison date_trunc vs time_bucket)
-- ============================================================================
\echo ''
\echo '📊 === Exemple 1: Prix moyen par mois ==='
\echo ''

\echo '--- Méthode classique avec date_trunc ---'
EXPLAIN ANALYZE
SELECT
    date_trunc('month', time) AS month,
    AVG(price) as avg_price,
    COUNT(*) as transactions
FROM tooth_loss
WHERE time > NOW() - INTERVAL '1 year'
GROUP BY month
ORDER BY month DESC;

\echo ''
\echo '--- Méthode TimescaleDB avec time_bucket (OPTIMISÉ) ---'
EXPLAIN ANALYZE
SELECT
    time_bucket('1 month', time) AS month,
    AVG(price) as avg_price,
    COUNT(*) as transactions
FROM tooth_loss
WHERE time > NOW() - INTERVAL '1 year'
GROUP BY month
ORDER BY month DESC;

-- ============================================================================
-- Exemple 2: Pics d'activité par heure et par pays
-- ============================================================================
\echo ''
\echo '📊 === Exemple 2: Pics d\'activité par heure (7 derniers jours) ==='
\echo ''

SELECT
    time_bucket('1 hour', time) AS hour,
    country,
    COUNT(*) as teeth_collected,
    ROUND(AVG(price)::numeric, 2) as avg_price,
    ROUND(SUM(price)::numeric, 2) as total_revenue
FROM tooth_loss
WHERE time > NOW() - INTERVAL '7 days'
GROUP BY hour, country
HAVING COUNT(*) > 100
ORDER BY teeth_collected DESC
LIMIT 20;

-- ============================================================================
-- Exemple 3: Top villes généreuses
-- ============================================================================
\echo ''
\echo '📊 === Exemple 3: Top 10 des villes les plus généreuses ==='
\echo ''

SELECT
    city,
    country,
    COUNT(*) as total_teeth,
    ROUND(AVG(price)::numeric, 2) as avg_price,
    ROUND(MIN(price)::numeric, 2) as min_price,
    ROUND(MAX(price)::numeric, 2) as max_price,
    ROUND(SUM(price)::numeric, 2) as total_revenue
FROM tooth_loss
WHERE time > NOW() - INTERVAL '1 year'
GROUP BY city, country
HAVING COUNT(*) > 100
ORDER BY avg_price DESC
LIMIT 10;

-- ============================================================================
-- Exemple 4: Évolution hebdomadaire avec window functions
-- ============================================================================
\echo ''
\echo '📊 === Exemple 4: Évolution du prix moyen par semaine (avec variation) ==='
\echo ''

WITH weekly_stats AS (
    SELECT
        time_bucket('1 week', time) AS week,
        ROUND(AVG(price)::numeric, 2) as avg_price,
        COUNT(*) as transactions
    FROM tooth_loss
    WHERE time > NOW() - INTERVAL '6 months'
    GROUP BY week
)
SELECT
    week,
    avg_price,
    transactions,
    LAG(avg_price) OVER (ORDER BY week) as prev_week_price,
    ROUND(
        ((avg_price - LAG(avg_price) OVER (ORDER BY week))
        / NULLIF(LAG(avg_price) OVER (ORDER BY week), 0) * 100)::numeric,
        2
    ) as variation_percent
FROM weekly_stats
ORDER BY week DESC
LIMIT 20;

-- ============================================================================
-- Exemple 5: Analyse par jour de la semaine
-- ============================================================================
\echo ''
\echo '📊 === Exemple 5: Analyse par jour de la semaine ==='
\echo ''

SELECT
    TO_CHAR(time, 'Day') as day_of_week,
    EXTRACT(DOW FROM time) as day_number,
    COUNT(*) as total_teeth,
    ROUND(AVG(price)::numeric, 2) as avg_price,
    COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() as percentage
FROM tooth_loss
WHERE time > NOW() - INTERVAL '3 months'
GROUP BY TO_CHAR(time, 'Day'), EXTRACT(DOW FROM time)
ORDER BY day_number;

-- ============================================================================
-- Exemple 6: Intervalle custom (toutes les 6 heures)
-- ============================================================================
\echo ''
\echo '📊 === Exemple 6: Agrégation toutes les 6 heures ==='
\echo ''

SELECT
    time_bucket('6 hours', time) AS period,
    COUNT(*) as transactions,
    ROUND(AVG(price)::numeric, 2) as avg_price,
    ROUND(MIN(price)::numeric, 2) as min_price,
    ROUND(MAX(price)::numeric, 2) as max_price
FROM tooth_loss
WHERE time > NOW() - INTERVAL '1 month'
GROUP BY period
ORDER BY period DESC
LIMIT 20;

-- ============================================================================
-- Exemple 7: Analyse des méthodes de paiement par pays
-- ============================================================================
\echo ''
\echo '📊 === Exemple 7: Répartition des méthodes de paiement par pays ==='
\echo ''

SELECT
    country,
    payment_method,
    COUNT(*) as transactions,
    ROUND(AVG(price)::numeric, 2) as avg_price,
    ROUND(
        (COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY country))::numeric,
        1
    ) as percentage_by_country
FROM tooth_loss
WHERE time > NOW() - INTERVAL '1 year'
GROUP BY country, payment_method
ORDER BY country, transactions DESC;

-- ============================================================================
-- Exemple 8: Détection d'anomalies (prix anormalement élevés)
-- ============================================================================
\echo ''
\echo '📊 === Exemple 8: Détection des prix anormalement élevés ==='
\echo ''

WITH stats AS (
    SELECT
        AVG(price) as mean,
        STDDEV(price) as stddev
    FROM tooth_loss
    WHERE time > NOW() - INTERVAL '1 month'
)
SELECT
    time_bucket('1 day', time) AS day,
    country,
    COUNT(*) as high_price_transactions,
    ROUND(AVG(price)::numeric, 2) as avg_high_price,
    ROUND((SELECT mean FROM stats)::numeric, 2) as overall_mean,
    ROUND((SELECT stddev FROM stats)::numeric, 2) as overall_stddev
FROM tooth_loss, stats
WHERE time > NOW() - INTERVAL '1 month'
  AND price > (stats.mean + 2 * stats.stddev)  -- Plus de 2 écarts-types
GROUP BY day, country
ORDER BY day DESC
LIMIT 20;

-- ============================================================================
-- Exemple 9: Analyse de la progression des dents par enfant
-- ============================================================================
\echo ''
\echo '📊 === Exemple 9: Enfants qui ont perdu le plus de dents (top 10) ==='
\echo ''

SELECT
    child_id,
    COUNT(*) as teeth_lost,
    ROUND(AVG(price)::numeric, 2) as avg_price_received,
    ROUND(SUM(price)::numeric, 2) as total_received,
    MIN(time) as first_tooth,
    MAX(time) as last_tooth,
    AGE(MAX(time), MIN(time)) as period
FROM tooth_loss
WHERE time > NOW() - INTERVAL '6 months'
GROUP BY child_id
HAVING COUNT(*) >= 3
ORDER BY teeth_lost DESC
LIMIT 10;

-- ============================================================================
-- Exemple 10: Performance monitoring - requête sur données récentes
-- ============================================================================
\echo ''
\echo '📊 === Exemple 10: Données en temps réel (dernières 24h) ==='
\echo ''

SELECT
    time_bucket('1 hour', time) AS hour,
    COUNT(*) as transactions,
    ROUND(AVG(price)::numeric, 2) as avg_price,
    COUNT(DISTINCT child_id) as unique_children,
    COUNT(DISTINCT country) as countries
FROM tooth_loss
WHERE time > NOW() - INTERVAL '24 hours'
GROUP BY hour
ORDER BY hour DESC;

\echo ''
\timing off
\echo '✅ Toutes les requêtes ont été exécutées avec succès !'
\echo ''
\echo '💡 Notez les temps d\'exécution grâce à TimescaleDB !'
\echo ''
