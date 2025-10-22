-- ============================================================================
-- Script 07: Fonctions spécifiques TimescaleDB (Gapfill, LOCF, Interpolate)
-- ============================================================================
-- Ce script démontre des fonctions uniques à TimescaleDB qui n'existent pas
-- dans PostgreSQL standard:
-- - time_bucket_gapfill() : Remplit les trous dans les séries temporelles
-- - locf() : Last Observation Carried Forward
-- - interpolate() : Interpolation linéaire
--
-- Usage: psql -h localhost -U postgres -d petite_souris -f scripts/07-gapfill.sql
-- ============================================================================

\echo '🦷 === Fonctions TimescaleDB : Gapfill & Interpolation ==='
\echo ''

-- ============================================================================
-- Étape 1: Problème - Données avec des trous
-- ============================================================================
\echo '📊 === Étape 1: Requête standard avec time_bucket (AVEC TROUS) ==='
\echo ''
\echo 'Requête standard - remarquez les minutes manquantes:'
\echo ''

SELECT
    time_bucket('1 minute', collected_at) AS minute,
    COUNT(*) as teeth_count,
    ROUND(AVG(price)::numeric, 2) as avg_price
FROM tooth_loss
WHERE collected_at > NOW() - INTERVAL '1 hour'
GROUP BY minute
ORDER BY minute DESC;

\echo ''
\echo '⚠️  Problème: Si aucune dent n''est tombée pendant 1 minute, la minute disparaît !'
\echo '⚠️  Conséquence: Graphiques avec trous, calculs de tendance difficiles'
\echo ''

-- ============================================================================
-- Étape 2: Solution TimescaleDB - time_bucket_gapfill()
-- ============================================================================
\echo '✨ === Étape 2: time_bucket_gapfill() - Remplir les trous ==='{
\echo ''
\echo 'Même requête avec time_bucket_gapfill() et BETWEEN:'
\echo ''

SELECT
    time_bucket_gapfill('1 minute', collected_at) AS minute,
    COUNT(*) as teeth_count,
    ROUND(AVG(price)::numeric, 2) as avg_price
FROM tooth_loss
WHERE collected_at BETWEEN NOW() - INTERVAL '1 hour' AND NOW()
GROUP BY minute
ORDER BY minute DESC;

\echo ''
\echo '✅ Toutes les 60 minutes apparaissent maintenant !'
\echo '📊 Les minutes sans données affichent 0 (COUNT) et NULL (AVG)'
\echo '💡 IMPORTANT: gapfill nécessite start ET finish (via BETWEEN ou arguments)'
\echo ''

-- ============================================================================
-- Étape 3: LOCF (Last Observation Carried Forward)
-- ============================================================================
\echo '🔄 === Étape 3: LOCF - Propager la dernière valeur connue ==='{
\echo ''
\echo 'Utile pour les métriques qui ne changent pas souvent (température, stock, etc.)'
\echo ''

SELECT
    time_bucket_gapfill('1 minute', collected_at) AS minute,
    COUNT(*) as teeth_count,
    locf(ROUND(AVG(price)::numeric, 2)) as avg_price_locf
FROM tooth_loss
WHERE collected_at BETWEEN NOW() - INTERVAL '1 hour' AND NOW()
GROUP BY minute
ORDER BY minute DESC;

\echo ''
\echo '✅ Les NULL sont remplacés par la dernière valeur connue'
\echo '💡 Parfait pour des dashboards temps réel (pas de trous visuels)'
\echo ''

-- ============================================================================
-- Étape 4: Interpolation linéaire
-- ============================================================================
\echo '📈 === Étape 4: Interpolation linéaire ==='{
\echo ''
\echo 'Calcule une valeur intermédiaire entre deux points connus:'
\echo ''

SELECT
    minute,
    teeth_count,
    ROUND(avg_price_interpolated::numeric, 2) as avg_price_interpolated
FROM (
    SELECT
        time_bucket_gapfill('1 minute', collected_at) AS minute,
        COUNT(*) as teeth_count,
        interpolate(AVG(price)) as avg_price_interpolated
    FROM tooth_loss
    WHERE collected_at BETWEEN NOW() - INTERVAL '1 hour' AND NOW()
    GROUP BY minute
) sub
ORDER BY minute DESC;

\echo ''
\echo '✅ Les trous sont remplis avec des valeurs interpolées linéairement'
\echo '💡 Utile pour lisser les données et détecter les tendances'
\echo ''

-- ============================================================================
-- Étape 5: Comparaison côte à côte
-- ============================================================================
\echo '🔍 === Étape 5: Comparaison des 3 approches ==='{
\echo ''

SELECT
    minute,
    teeth_count,
    ROUND(price_raw::numeric, 2) as price_raw,
    ROUND(price_locf::numeric, 2) as price_locf,
    ROUND(price_interpolate::numeric, 2) as price_interpolate
FROM (
    SELECT
        time_bucket_gapfill('1 minute', collected_at) AS minute,
        COUNT(*) as teeth_count,
        AVG(price) as price_raw,
        locf(AVG(price)) as price_locf,
        interpolate(AVG(price)) as price_interpolate
    FROM tooth_loss
    WHERE collected_at BETWEEN NOW() - INTERVAL '1 hour' AND NOW()
    GROUP BY minute
) sub
ORDER BY minute DESC;

\echo ''
\echo '📊 Colonnes:'
\echo '   - price_raw: NULL si pas de données (défaut)'
\echo '   - price_locf: Répète la dernière valeur connue'
\echo '   - price_interpolate: Calcule une valeur intermédiaire'
\echo ''

-- ============================================================================
-- Étape 6: Cas d'usage réel - Revenue par heure avec gapfill
-- ============================================================================
\echo '💰 === Étape 6: Revenue horaire sur 24h (avec tous les trous remplis) ==='{
\echo ''

SELECT
    time_bucket_gapfill('1 hour', collected_at) AS hour,
    COUNT(*) as teeth_count,
    COALESCE(ROUND(SUM(price)::numeric, 2), 0) as revenue,
    locf(ROUND(SUM(price)::numeric, 2), 0::numeric) as revenue_locf
FROM tooth_loss
WHERE collected_at BETWEEN NOW() - INTERVAL '24 hours' AND NOW()
GROUP BY hour
ORDER BY hour DESC;

\echo ''
\echo '💡 Notez: COALESCE transforme NULL en 0 pour le revenue'
\echo '💡 locf avec valeur par défaut évite les NULL en début de série'
\echo ''

-- ============================================================================
-- Étape 7: Gapfill avec start/end explicites
-- ============================================================================
\echo '⏱️  === Étape 7: Gapfill avec fenêtre de temps explicite ==='{
\echo ''
\echo 'Forcer une fenêtre temporelle précise (même si pas de données):'
\echo ''

SELECT
    time_bucket_gapfill('1 minute', collected_at,
        start => NOW() - INTERVAL '1 hour',
        finish => NOW()
    ) AS minute,
    COUNT(*) as teeth_count,
    locf(ROUND(AVG(price)::numeric, 2), 0::numeric) as avg_price
FROM tooth_loss
WHERE collected_at BETWEEN NOW() - INTERVAL '1 hour' AND NOW()
GROUP BY minute
ORDER BY minute DESC;

\echo ''
\echo '✅ Garantit exactement 60 minutes de données (3600 secondes / 60 = 60 buckets)'
\echo '💡 Alternative au BETWEEN: passer start/finish en arguments'
\echo ''

-- ============================================================================
-- Étape 8: Cas d'usage - Détecter les périodes sans activité
-- ============================================================================
\echo '🔍 === Étape 8: Détecter les périodes sans activité ==='{
\echo ''

SELECT
    time_bucket_gapfill('1 minute', collected_at) AS minute,
    COUNT(*) as teeth_count,
    CASE
        WHEN COUNT(*) = 0 THEN '⚠️  Aucune activité'
        WHEN COUNT(*) < 5 THEN '🔶 Activité faible'
        ELSE '✅ Activité normale'
    END as status
FROM tooth_loss
WHERE collected_at BETWEEN NOW() - INTERVAL '1 hour' AND NOW()
GROUP BY minute
ORDER BY minute DESC;

\echo ''
\echo '💡 Grâce au gapfill, on peut identifier facilement les périodes creuses'
\echo ''

-- ============================================================================
-- Résumé
-- ============================================================================
\echo ''
\echo '🎉 Démonstration des fonctions TimescaleDB terminée !'
\echo ''
\echo '📊 Fonctions uniques à TimescaleDB présentées:'
\echo ''
\echo '1️⃣  time_bucket_gapfill()'
\echo '   → Remplit automatiquement les trous dans les séries temporelles'
\echo '   → Essentiel pour des graphiques sans trous'
\echo '   → Fonctionne avec start/finish pour contrôler la fenêtre'
\echo ''
\echo '2️⃣  locf() - Last Observation Carried Forward'
\echo '   → Propage la dernière valeur connue'
\echo '   → Parfait pour les métriques qui changent peu'
\echo '   → Accepte une valeur par défaut'
\echo ''
\echo '3️⃣  interpolate()'
\echo '   → Interpolation linéaire entre deux points'
\echo '   → Lisse les données'
\echo '   → Utile pour détecter les tendances'
\echo ''
\echo '💡 Cas d''usage typiques:'
\echo '   • Dashboards temps réel (pas de trous visuels)'
\echo '   • Détection d''anomalies (périodes sans activité)'
\echo '   • Machine Learning (features complètes sans NULL)'
\echo '   • Calculs de moyennes mobiles'
\echo ''
\echo '🔥 Différence clé avec PostgreSQL standard:'
\echo '   PostgreSQL: time_bucket() → trous dans les données'
\echo '   TimescaleDB: time_bucket_gapfill() → série temporelle complète'
\echo ''

-- ============================================================================
-- NOTES POUR LA PRÉSENTATION
-- ============================================================================
-- 1. Commencer par montrer le problème: requête standard avec trous
-- 2. Introduire gapfill comme "la solution TimescaleDB"
-- 3. Montrer LOCF pour les dashboards en temps réel
-- 4. Montrer interpolate pour le lissage
-- 5. Comparaison côte à côte pour voir les différences
-- 6. Insister sur: "Ces fonctions n'existent PAS dans PostgreSQL standard"
-- 7. Mentionner les use cases: dashboards, ML, détection d'anomalies
-- ============================================================================
