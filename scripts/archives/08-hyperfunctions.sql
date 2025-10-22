-- ============================================================================
-- Script 08: Hyperfunctions TimescaleDB (Stats, Pipelines, Percentiles)
-- ============================================================================
-- Ce script démontre les hyperfunctions avancées de TimescaleDB:
-- - stats_agg() : Aggrégations statistiques multiples en un seul scan
-- - Function pipelines : Composition de fonctions lisible (opérateur ->)
-- - percentile_agg() : Percentiles approximatifs ultra-rapides
-- - first() / last() : Première/dernière valeur par timestamp
--
-- Note: Nécessite l'extension timescaledb_toolkit (incluse dans timescale/timescaledb-ha)
--
-- Usage: psql -h localhost -U postgres -d petite_souris -f scripts/08-hyperfunctions.sql
-- ============================================================================

\echo '🦷 === Hyperfunctions TimescaleDB : Stats, Pipelines & Percentiles ==='
\echo ''

-- ============================================================================
-- Étape 1: Le problème - Calculs statistiques multiples
-- ============================================================================
\echo '📊 === Étape 1: PostgreSQL standard - Plusieurs scans de table ==='{
\echo ''
\echo 'Pour obtenir plusieurs statistiques, PostgreSQL scan la table plusieurs fois:'
\echo ''

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    country_code,
    AVG(price) as moyenne,
    STDDEV(price) as ecart_type,
    VARIANCE(price) as variance,
    COUNT(*) as nb_dents
FROM tooth_loss
WHERE collected_at > NOW() - INTERVAL '24 hours'
GROUP BY country_code
ORDER BY country_code;

\echo ''
\echo '⚠️  Problème: Même si optimisé, chaque agrégation parcourt les données'
\echo '⚠️  Sur de gros volumes: temps CPU et I/O importants'
\echo ''

-- ============================================================================
-- Étape 2: Solution TimescaleDB - stats_agg()
-- ============================================================================
\echo '✨ === Étape 2: stats_agg() - Un scan, toutes les stats ==='{
\echo ''
\echo 'TimescaleDB stats_agg() calcule TOUT en un seul passage:'
\echo ''

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

\echo ''
\echo '✅ Un seul scan de la table pour 5 statistiques différentes !'
\echo '💡 stats_agg() pré-calcule tout, les accesseurs (average, stddev...) sont quasi-gratuits'
\echo ''

-- ============================================================================
-- Étape 3: Introduction aux Function Pipelines
-- ============================================================================
\echo '🔄 === Étape 3: Function Pipelines - Lisibilité améliorée ==='{
\echo ''
\echo 'Comparaison: syntaxe imbriquée vs pipeline operator (->)'
\echo ''

\echo '--- Version classique (nested functions) ---'
SELECT
    country_code,
    average(stats_agg(price)) as avg_price,
    stddev(stats_agg(price)) as stddev_price
FROM tooth_loss
WHERE collected_at > NOW() - INTERVAL '24 hours'
GROUP BY country_code
ORDER BY avg_price DESC
LIMIT 5;

\echo ''
\echo '--- Version pipeline (-> operator) - EXPERIMENTAL ---'
SELECT
    country_code,
    stats_agg(price) -> average() as avg_price,
    stats_agg(price) -> stddev() as stddev_price
FROM tooth_loss
WHERE collected_at > NOW() - INTERVAL '24 hours'
GROUP BY country_code
ORDER BY avg_price DESC
LIMIT 5;

\echo ''
\echo '✅ Pipeline: lecture naturelle de gauche à droite'
\echo '💡 Comme les Unix pipes: data | transform | extract'
\echo '💡 EXPERIMENTAL mais déjà très utile pour la composition'
\echo ''

-- ============================================================================
-- Étape 4: Percentiles approximatifs
-- ============================================================================
\echo '📈 === Étape 4: Percentiles approximatifs (P50, P95, P99) ==='{
\echo ''
\echo 'Calcul rapide de percentiles sans tri complet de la table:'
\echo ''

SELECT
    country_code,
    approx_percentile(0.50, percentile_agg(price)) as p50_mediane,
    approx_percentile(0.95, percentile_agg(price)) as p95,
    approx_percentile(0.99, percentile_agg(price)) as p99,
    MAX(price) as max_price
FROM tooth_loss
WHERE collected_at > NOW() - INTERVAL '24 hours'
GROUP BY country_code
ORDER BY country_code;

\echo ''
\echo '✅ Percentiles calculés via algorithme t-digest (approximation)'
\echo '💡 Cas d''usage: SLA (p95 latency), détection anomalies, pricing'
\echo '💡 Beaucoup plus rapide que ORDER BY + LIMIT sur gros volumes'
\echo ''

-- ============================================================================
-- Étape 5: Percentiles avec pipelines
-- ============================================================================
\echo '🔄 === Étape 5: Percentiles avec pipeline syntax ==='{
\echo ''

SELECT
    country_code,
    percentile_agg(price) -> approx_percentile(0.50) as p50,
    percentile_agg(price) -> approx_percentile(0.95) as p95,
    percentile_agg(price) -> approx_percentile(0.99) as p99
FROM tooth_loss
WHERE collected_at > NOW() - INTERVAL '24 hours'
GROUP BY country_code
ORDER BY country_code;

\echo ''
\echo '💡 Encore plus lisible: percentile_agg() -> approx_percentile(0.95)'
\echo ''

-- ============================================================================
-- Étape 6: first() et last() - Valeurs temporelles
-- ============================================================================
\echo '⏰ === Étape 6: first() / last() - Première et dernière valeur par temps ==='{
\echo ''
\echo 'PostgreSQL n''a pas de first/last fiable par timestamp.'
\echo 'TimescaleDB: first(value, time) et last(value, time)'
\echo ''

SELECT
    country_code,
    first(price, collected_at) as prix_initial,
    last(price, collected_at) as prix_actuel,
    ROUND((last(price, collected_at) - first(price, collected_at))::numeric, 2) as evolution,
    COUNT(*) as nb_dents
FROM tooth_loss
GROUP BY country_code
ORDER BY evolution DESC;

\echo ''
\echo '✅ first() = première valeur chronologique (plus ancien timestamp)'
\echo '✅ last() = dernière valeur chronologique (plus récent timestamp)'
\echo '💡 Cas d''usage: IoT (dernière valeur capteur), finance (cours ouverture/clôture)'
\echo '💡 Exemple: La petite souris française a augmenté ses prix ! 📈'
\echo ''

-- ============================================================================
-- Étape 7: Combinaison - Stats + First/Last par pays
-- ============================================================================
\echo '🌍 === Étape 7: Vue complète - Stats + Evolution par pays ==='{
\echo ''

SELECT
    country_code,
    COUNT(*) as total_dents,
    stats_agg(price) -> average() as prix_moyen,
    stats_agg(price) -> stddev() as volatilite,
    first(price, collected_at) as prix_debut,
    last(price, collected_at) as prix_fin,
    percentile_agg(price) -> approx_percentile(0.50) as prix_median,
    percentile_agg(price) -> approx_percentile(0.95) as prix_p95
FROM tooth_loss
WHERE collected_at > NOW() - INTERVAL '7 days'
GROUP BY country_code
ORDER BY total_dents DESC;

\echo ''
\echo '💎 Toutes les hyperfunctions en une seule requête !'
\echo '💡 Stats complètes par pays en un seul scan de table'
\echo ''

-- ============================================================================
-- Étape 8: Rolling aggregates avec pipelines
-- ============================================================================
\echo '📊 === Étape 8: Rolling aggregates - Moyennes mobiles ==='{
\echo ''
\echo 'Moyenne mobile sur 5 heures avec function pipelines:'
\echo ''

SELECT
    time_bucket('1 hour', collected_at) as hour,
    COUNT(*) as dents_cette_heure,
    AVG(price) as prix_moyen_heure,
    stats_agg(price) -> rolling(bucket_width => 5) -> average() as prix_moyen_mobile_5h
FROM tooth_loss
WHERE collected_at > NOW() - INTERVAL '48 hours'
GROUP BY hour
ORDER BY hour DESC
LIMIT 24;

\echo ''
\echo '✅ rolling() crée une fenêtre glissante de N buckets'
\echo '💡 Lisse les variations et montre les tendances'
\echo '💡 Pipeline syntax: stats_agg() -> rolling() -> average()'
\echo ''

-- ============================================================================
-- Étape 9: Cas d'usage - Détection d'anomalies
-- ============================================================================
\echo '🚨 === Étape 9: Détection d''anomalies avec stats ==='{
\echo ''
\echo 'Prix anormalement hauts: > moyenne + 2 × écart-type'
\echo ''

WITH stats AS (
    SELECT
        stats_agg(price) -> average() as avg,
        stats_agg(price) -> stddev() as stddev
    FROM tooth_loss
    WHERE collected_at > NOW() - INTERVAL '24 hours'
)
SELECT
    collected_at,
    child_id,
    tooth_number,
    country_code,
    price,
    ROUND((price - stats.avg)::numeric, 2) as ecart_moyenne,
    ROUND(((price - stats.avg) / NULLIF(stats.stddev, 0))::numeric, 2) as z_score
FROM tooth_loss, stats
WHERE collected_at > NOW() - INTERVAL '24 hours'
  AND price > (stats.avg + 2 * stats.stddev)
ORDER BY price DESC
LIMIT 10;

\echo ''
\echo '💡 z_score > 2 = anomalie (prix anormalement élevé)'
\echo '💡 Utile pour détecter les fraudes, erreurs de saisie, comportements suspects'
\echo ''

-- ============================================================================
-- Résumé
-- ============================================================================
\echo ''
\echo '🎉 Démonstration des Hyperfunctions terminée !'
\echo ''
\echo '📊 Hyperfunctions présentées:'
\echo ''
\echo '1️⃣  stats_agg() + accesseurs (average, stddev, variance, sum, num_vals)'
\echo '   → Un seul scan pour toutes les statistiques'
\echo '   → Performance optimale sur gros volumes'
\echo ''
\echo '2️⃣  Function Pipelines (opérateur ->)'
\echo '   → Syntaxe lisible: data -> transform -> extract'
\echo '   → Composition naturelle de fonctions'
\echo '   → EXPERIMENTAL mais très pratique'
\echo ''
\echo '3️⃣  percentile_agg() + approx_percentile()'
\echo '   → Calcul rapide de P50, P95, P99'
\echo '   → Algorithme t-digest (approximation précise)'
\echo '   → Essentiel pour SLA et monitoring'
\echo ''
\echo '4️⃣  first() / last()'
\echo '   → Première/dernière valeur par timestamp'
\echo '   → Natif TimescaleDB (pas dans PostgreSQL standard)'
\echo '   → Parfait pour IoT, finance, monitoring'
\echo ''
\echo '5️⃣  rolling() aggregates'
\echo '   → Moyennes mobiles et fenêtres glissantes'
\echo '   → Détection de tendances'
\echo '   → S''utilise avec pipelines pour plus de lisibilité'
\echo ''
\echo '💡 Cas d''usage typiques:'
\echo '   • Monitoring: P95 latency, moyennes mobiles'
\echo '   • Finance: Prix min/max/moyen, volatilité, cours ouverture/clôture'
\echo '   • IoT: Dernière valeur capteur, stats par device'
\echo '   • Détection anomalies: Z-score, valeurs extrêmes'
\echo '   • SLA: Percentiles de temps de réponse'
\echo ''
\echo '🔥 Différence clé avec PostgreSQL standard:'
\echo '   PostgreSQL: Multiples scans ou calculs complexes'
\echo '   TimescaleDB: Un scan, hyperfunctions optimisées, pipelines lisibles'
\echo ''

-- ============================================================================
-- NOTES POUR LA PRÉSENTATION
-- ============================================================================
-- 1. Commencer par montrer le problème: plusieurs scans pour plusieurs stats
-- 2. Introduire stats_agg(): un scan, tout calculé
-- 3. Montrer la syntaxe pipeline: lisibilité++
-- 4. Percentiles: cas concret SLA (p95 < 100ms)
-- 5. first/last: exemple IoT ou finance
-- 6. Rolling: montrer une tendance lissée
-- 7. Finir avec détection anomalies (z-score)
--
-- Points à mentionner:
-- - Hyperfunctions = fonctions optimisées TimescaleDB
-- - Pipelines = EXPERIMENTAL mais safe et utile
-- - Performance: un seul scan vs multiples
-- - Composition: combiner les fonctions facilement
-- ============================================================================
