-- ============================================================================
-- Requêtes pour la présentation - Hyperfunctions TimescaleDB
-- ============================================================================
-- Ce fichier contient toutes les requêtes montrées dans les slides,
-- dans l'ordre de présentation, prêtes à copier-coller.
--
-- Ordre des slides:
-- 1. Problème : Trous dans les séries temporelles
-- 2. Solution : time_bucket_gapfill()
-- 3. Bonus : locf()
-- 4. Problème : Multiples agrégations PostgreSQL
-- 5. Solution : stats_agg()
-- 6. Pipelines : Avant (nested)
-- 7. Pipelines : Après (->)
-- 8. Percentiles approximatifs
-- 9. first() / last()
-- ============================================================================

-- ============================================================================
-- SLIDE 1 : Problème - Trous dans les séries temporelles
-- ============================================================================

SELECT
    time_bucket('1 minute', collected_at) AS minute,
    COUNT(*) as teeth_count,
    ROUND(AVG(price)::numeric, 2) as avg_price
FROM tooth_loss
WHERE collected_at > NOW() - INTERVAL '1 hour'
GROUP BY minute
ORDER BY minute DESC;

-- Résultat attendu : ~23 lignes au lieu de 60 → Trous !

-- ============================================================================
-- SLIDE 2 : Solution - time_bucket_gapfill()
-- ============================================================================

SELECT
    time_bucket_gapfill('1 minute', collected_at) AS minute,
    COUNT(*) as teeth_count,
    ROUND(AVG(price)::numeric, 2) as avg_price
FROM tooth_loss
WHERE collected_at BETWEEN NOW() - INTERVAL '1 hour' AND NOW()
GROUP BY minute
ORDER BY minute DESC;

-- Résultat attendu : Exactement 60 lignes → Série complète !

-- ============================================================================
-- SLIDE 3 : Bonus - locf() (Last Observation Carried Forward)
-- ============================================================================

SELECT
    time_bucket_gapfill('1 minute', collected_at) AS minute,
    COUNT(*) as teeth_count,
    locf(ROUND(AVG(price)::numeric, 2)) as avg_price_locf
FROM tooth_loss
WHERE collected_at BETWEEN NOW() - INTERVAL '1 hour' AND NOW()
GROUP BY minute
ORDER BY minute DESC;

-- Résultat attendu : Plus de NULL, valeurs propagées !

-- ============================================================================
-- SLIDE 4 : Problème - Multiples agrégations PostgreSQL standard
-- ============================================================================

-- Plusieurs agrégations = potentiellement plusieurs scans
SELECT country_code,
       AVG(price) as moyenne,
       STDDEV(price) as ecart_type,
       VARIANCE(price) as variance
FROM tooth_loss
WHERE collected_at > NOW() - INTERVAL '24 hours'
GROUP BY country_code;

-- ============================================================================
-- SLIDE 5 : Solution - stats_agg() (Un scan, toutes les stats)
-- ============================================================================

SELECT
    country_code,
    average(stats_agg(price)) as moyenne,
    stddev(stats_agg(price)) as ecart_type,
    variance(stats_agg(price)) as variance,
    sum(stats_agg(price)) as total,
    num_vals(stats_agg(price)) as nb_dents
FROM tooth_loss
WHERE collected_at > NOW() - INTERVAL '24 hours'
GROUP BY country_code
ORDER BY country_code;

-- Résultat : Un seul scan pour 5 statistiques !

-- ============================================================================
-- SLIDE 6 : Pipelines - Syntaxe imbriquée (AVANT)
-- ============================================================================

SELECT country_code,
       average(stats_agg(price)) as avg,
       approx_percentile(0.95, percentile_agg(price)) as p95
FROM tooth_loss
WHERE collected_at > NOW() - INTERVAL '24 hours'
GROUP BY country_code;

-- ============================================================================
-- SLIDE 7 : Pipelines - Opérateur -> (APRÈS)
-- ============================================================================

SELECT country_code,
       stats_agg(price) -> average() as avg,
       percentile_agg(price) -> approx_percentile(0.95) as p95
FROM tooth_loss
WHERE collected_at > NOW() - INTERVAL '24 hours'
GROUP BY country_code;

-- Même résultat, mais lecture naturelle gauche → droite !

-- ============================================================================
-- SLIDE 8 : Percentiles approximatifs (P50, P95, P99)
-- ============================================================================

SELECT
    country_code,
    percentile_agg(price) -> approx_percentile(0.50) as p50_median,
    percentile_agg(price) -> approx_percentile(0.95) as p95,
    percentile_agg(price) -> approx_percentile(0.99) as p99
FROM tooth_loss
WHERE collected_at > NOW() - INTERVAL '24 hours'
GROUP BY country_code
ORDER BY p95 DESC
LIMIT 10;

-- Résultat : P50, P95, P99 ultra-rapides avec algorithme t-digest

-- ============================================================================
-- SLIDE 9 : first() / last() - Évolution temporelle
-- ============================================================================

SELECT
    country_code,
    first(price, collected_at) as prix_initial,
    last(price, collected_at) as prix_actuel,
    ROUND((last(price, collected_at) - first(price, collected_at))::numeric, 2)
        as evolution
FROM tooth_loss
GROUP BY country_code
ORDER BY evolution DESC
LIMIT 10;

-- Résultat : "La petite souris française a augmenté ses prix !"

-- ============================================================================
-- BONUS : Continuous Aggregates + stats_agg()
-- ============================================================================
-- Cette partie montre le vrai pouvoir de stats_agg() combiné avec les caggs
-- (À utiliser dans la démo Continuous Aggregates, pas dans les hyperfunctions)

-- Créer un cagg avec stats_agg matérialisé
CREATE MATERIALIZED VIEW IF NOT EXISTS daily_stats_advanced
WITH (timescaledb.continuous, timescaledb.materialized_only = false) AS
SELECT
    time_bucket('1 day', collected_at) AS day,
    country_code,
    stats_agg(price) as price_stats  -- Calculé UNE FOIS, matérialisé
FROM tooth_loss
GROUP BY day, country_code;

-- Rafraîchir le cagg
CALL refresh_continuous_aggregate('daily_stats_advanced', NULL, NULL);

-- Extraire plusieurs stats = GRATUIT (accesseurs sur le stats_agg matérialisé)
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

-- Comparaison EXPLAIN ANALYZE

-- 1. Recalculer (scan la hypertable)
EXPLAIN (ANALYZE, BUFFERS)
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

-- 2. Extraire depuis cagg (lecture de la vue matérialisée)
EXPLAIN (ANALYZE, BUFFERS)
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

-- Résultat attendu: 10-100x plus rapide avec le cagg !

-- ============================================================================
-- NOTES POUR LA PRÉSENTATION
-- ============================================================================
--
-- Préparation avant la présentation:
-- 1. Lancer: make 01-test (setup rapide avec 100 enfants)
-- 2. Lancer: make backfill (données dernière heure pour gapfill)
-- 3. Lancer: make backfill-historical-test (1 an de données pour stats)
--
-- Ordre de présentation:
-- 1. Montrer le problème avec time_bucket classique (trous)
-- 2. Montrer la solution avec gapfill (60 lignes exactement)
-- 3. Montrer locf() pour propager les valeurs
-- 4. Montrer le problème des multiples agrégations
-- 5. Montrer stats_agg() qui fait tout en un scan
-- 6. Montrer la syntaxe nested (avant)
-- 7. Montrer la syntaxe pipeline (après) - WOW effect
-- 8. Montrer les percentiles (P95 pour SLA)
-- 9. Montrer first/last pour l'évolution temporelle
--
-- Points clés à mentionner:
-- - gapfill/locf/interpolate n'existent PAS dans PostgreSQL standard
-- - stats_agg optimise les performances (un seul scan)
-- - Pipelines = EXPERIMENTAL mais stable et très pratique
-- - Percentiles approximatifs = algorithme t-digest
-- - first/last par timestamp = natif TimescaleDB
--
-- ============================================================================
