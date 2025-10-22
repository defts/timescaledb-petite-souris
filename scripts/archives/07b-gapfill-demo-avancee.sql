-- ============================================================================
-- Script 07b: Démo avancée Gapfill avec données d'octobre
-- ============================================================================
-- Requête démo qui montre :
-- - time_bucket_gapfill pour remplir les trous
-- - Window functions (cumul par jour)
-- - Rollup par groupe d'âge (6 ans vs 7 ans + total)
-- - Clause WHERE avec BETWEEN pour activer gapfill
--
-- Prérequis: Avoir rempli la base avec des données historiques d'octobre
--   ./bin/datagen backfill-historical --years 1 --rate 10000
--
-- Usage: psql -h localhost -U postgres -d petite_souris -f scripts/07b-gapfill-demo-avancee.sql
-- ============================================================================

\echo '🦷 === Démo Gapfill Avancée : Analyse par âge avec window functions ==='
\echo ''

-- ============================================================================
-- Étape 1: Vérifier qu'on a bien des données en octobre 2024
-- ============================================================================
\echo '📊 === Vérification des données disponibles ==='
\echo ''

SELECT
    DATE_TRUNC('month', collected_at) AS month,
    COUNT(*) as records,
    MIN(collected_at) as first_record,
    MAX(collected_at) as last_record
FROM tooth_loss
WHERE collected_at >= '2024-10-01' AND collected_at < '2024-12-01'
GROUP BY month
ORDER BY month;

\echo ''
\echo '💡 On devrait voir des données pour octobre et novembre 2024'
\echo ''

-- ============================================================================
-- Étape 2: Dents perdues par heure avec gapfill (octobre 2024)
-- ============================================================================
\echo '📈 === Dents perdues par heure en octobre 2024 (avec gapfill) ==='
\echo ''
\echo 'Tous les créneaux horaires apparaissent grâce à time_bucket_gapfill():'
\echo ''

SELECT
    time_bucket_gapfill('1 hour', collected_at) AS hour,
    COUNT(*) as teeth_lost,
    COALESCE(COUNT(*), 0) as teeth_lost_filled
FROM tooth_loss
WHERE collected_at BETWEEN '2024-10-01' AND '2024-10-31 23:59:59'
GROUP BY hour
ORDER BY hour
LIMIT 50;

\echo ''
\echo '✅ Toutes les heures sont présentes (744 heures en octobre = 31 jours × 24h)'
\echo '💡 Les heures sans données affichent 0 grâce à COALESCE'
\echo ''

-- ============================================================================
-- Étape 3: Analyse par âge d'enfant avec window function
-- ============================================================================
\echo '👶 === Dents perdues par jour avec cumul et segmentation par âge ==='{
\echo ''
\echo 'Analyse des enfants de 6-7 ans avec cumul journalier:'
\echo ''

-- Créer une vue temporaire avec l'âge des enfants
CREATE TEMP VIEW tooth_loss_with_age AS
SELECT
    tl.collected_at,
    tl.child_id,
    tl.tooth_number,
    tl.price,
    tl.country_code,
    EXTRACT(YEAR FROM AGE(tl.collected_at, c.birth_date)) AS age_years
FROM tooth_loss tl
JOIN children c ON tl.child_id = c.child_id;

\echo '✅ Vue temporaire créée avec l''âge des enfants'
\echo ''

-- Requête principale avec gapfill, window functions et rollup
\echo 'Requête avec gapfill + window function + rollup par âge:'
\echo ''

WITH daily_stats AS (
    SELECT
        time_bucket_gapfill('1 day', collected_at) AS day,
        CASE
            WHEN age_years = 6 THEN '6 ans'
            WHEN age_years = 7 THEN '7 ans'
            ELSE 'Autre'
        END AS age_group,
        COUNT(*) as teeth_count,
        ROUND(AVG(price)::numeric, 2) as avg_price
    FROM tooth_loss_with_age
    WHERE
        collected_at BETWEEN '2024-10-01' AND '2024-10-31 23:59:59'
        AND age_years IN (6, 7)  -- Filtrer uniquement 6 et 7 ans
    GROUP BY day, age_group
)
SELECT
    day,
    age_group,
    teeth_count,
    avg_price,
    -- Window function: cumul par groupe d'âge
    SUM(teeth_count) OVER (
        PARTITION BY age_group
        ORDER BY day
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) as cumulative_teeth,
    -- Window function: moyenne mobile sur 3 jours
    ROUND(
        AVG(teeth_count) OVER (
            PARTITION BY age_group
            ORDER BY day
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        )::numeric, 1
    ) as moving_avg_3days
FROM daily_stats
ORDER BY day, age_group
LIMIT 50;

\echo ''
\echo '📊 Colonnes:'
\echo '   - day: Jour (tous les jours grâce à gapfill)'
\echo '   - age_group: Groupe d''âge (6 ans ou 7 ans)'
\echo '   - teeth_count: Nombre de dents perdues ce jour'
\echo '   - avg_price: Prix moyen payé'
\echo '   - cumulative_teeth: Cumul depuis le début du mois (window function)'
\echo '   - moving_avg_3days: Moyenne mobile sur 3 jours'
\echo ''
\echo '💡 Les window functions permettent de calculer des cumuls et moyennes mobiles'
\echo '💡 PARTITION BY age_group fait des calculs séparés pour chaque groupe d''âge'
\echo ''

-- ============================================================================
-- Étape 4: Rollup avec GROUPING SETS pour avoir le total
-- ============================================================================
\echo '📊 === Rollup : 6 ans + 7 ans + TOTAL ==='{
\echo ''
\echo 'Utilisation de GROUPING SETS pour avoir les sous-totaux:'
\echo ''

SELECT
    day,
    COALESCE(age_group, '🔢 TOTAL') as age_group,
    SUM(teeth_count) as total_teeth,
    ROUND(AVG(avg_price)::numeric, 2) as avg_price
FROM (
    SELECT
        time_bucket_gapfill('1 day', collected_at) AS day,
        CASE
            WHEN age_years = 6 THEN '6 ans'
            WHEN age_years = 7 THEN '7 ans'
        END AS age_group,
        COUNT(*) as teeth_count,
        AVG(price) as avg_price
    FROM tooth_loss_with_age
    WHERE
        collected_at BETWEEN '2024-10-01' AND '2024-10-31 23:59:59'
        AND age_years IN (6, 7)
    GROUP BY day, age_group
) daily_data
GROUP BY GROUPING SETS (
    (day, age_group),  -- Détail par groupe
    (day)              -- Total par jour
)
ORDER BY day, age_group NULLS LAST
LIMIT 50;

\echo ''
\echo '✅ GROUPING SETS permet d''avoir:'
\echo '   - Une ligne pour les enfants de 6 ans'
\echo '   - Une ligne pour les enfants de 7 ans'
\echo '   - Une ligne TOTAL (age_group = NULL converti en "TOTAL")'
\echo ''
\echo '💡 Alternative: ROLLUP(day, age_group) ou CUBE() selon les besoins'
\echo ''

-- ============================================================================
-- Étape 5: Comparaison AVEC et SANS gapfill
-- ============================================================================
\echo '🔍 === Comparaison : Avec vs Sans gapfill ==='{
\echo ''

\echo 'SANS gapfill (les jours sans données disparaissent):'
\echo ''

SELECT
    time_bucket('1 day', collected_at) AS day,
    COUNT(*) as teeth_count
FROM tooth_loss_with_age
WHERE
    collected_at >= '2024-10-01' AND collected_at < '2024-10-08'
    AND age_years = 6
GROUP BY day
ORDER BY day;

\echo ''
\echo 'AVEC gapfill (tous les jours apparaissent):'
\echo ''

SELECT
    time_bucket_gapfill('1 day', collected_at) AS day,
    COUNT(*) as teeth_count
FROM tooth_loss_with_age
WHERE
    collected_at BETWEEN '2024-10-01' AND '2024-10-07 23:59:59'
    AND age_years = 6
GROUP BY day
ORDER BY day;

\echo ''
\echo '💡 Notez la différence:'
\echo '   - Sans gapfill: certains jours peuvent manquer'
\echo '   - Avec gapfill: tous les jours de la semaine sont présents'
\echo ''

-- ============================================================================
-- Étape 6: Démo complète avec LOCF pour les trous
-- ============================================================================
\echo '🔄 === Gapfill + LOCF pour propager les valeurs ==='{
\echo ''

SELECT
    day,
    age_group,
    teeth_count,
    teeth_count_locf
FROM (
    SELECT
        time_bucket_gapfill('1 day', collected_at) AS day,
        CASE
            WHEN age_years = 6 THEN '6 ans'
            WHEN age_years = 7 THEN '7 ans'
        END AS age_group,
        COUNT(*) as teeth_count,
        locf(COUNT(*)) as teeth_count_locf
    FROM tooth_loss_with_age
    WHERE
        collected_at BETWEEN '2024-10-01' AND '2024-10-15 23:59:59'
        AND age_years IN (6, 7)
    GROUP BY day, age_group
) sub
WHERE age_group IS NOT NULL
ORDER BY day, age_group
LIMIT 50;

\echo ''
\echo '📊 Colonnes:'
\echo '   - teeth_count: Valeur réelle (0 si pas de données ce jour)'
\echo '   - teeth_count_locf: Dernière valeur connue propagée'
\echo ''
\echo '💡 LOCF est utile pour les dashboards temps réel'
\echo ''

-- ============================================================================
-- Résumé
-- ============================================================================
\echo ''
\echo '🎉 Démo avancée terminée !'
\echo ''
\echo '📊 Ce qu''on a montré:'
\echo ''
\echo '1️⃣  time_bucket_gapfill avec BETWEEN'
\echo '   → Remplit automatiquement les trous dans les séries temporelles'
\echo '   → Garantit que tous les créneaux temporels sont présents'
\echo ''
\echo '2️⃣  Window Functions'
\echo '   → Cumul par groupe d''âge (SUM OVER avec PARTITION BY)'
\echo '   → Moyenne mobile sur 3 jours (AVG OVER avec ROWS BETWEEN)'
\echo ''
\echo '3️⃣  GROUPING SETS pour rollup'
\echo '   → Détail par groupe d''âge (6 ans, 7 ans)'
\echo '   → Total agrégé sur tous les groupes'
\echo ''
\echo '4️⃣  LOCF (Last Observation Carried Forward)'
\echo '   → Propage la dernière valeur connue'
\echo '   → Évite les trous visuels dans les dashboards'
\echo ''
\echo '💡 Pourquoi c''est puissant ?'
\echo '   • Ces fonctions n''existent PAS dans PostgreSQL standard'
\echo '   • Simplifie énormément le code (pas besoin de generate_series complexes)'
\echo '   • Optimisé pour les performances sur grandes séries temporelles'
\echo '   • Essentiel pour ML, dashboards, et analyses de tendances'
\echo ''
\echo '🔥 Cas d''usage typiques:'
\echo '   • Dashboards temps réel sans trous visuels'
\echo '   • Détection d''anomalies (périodes sans activité)'
\echo '   • Machine Learning (features complètes sans NULL)'
\echo '   • Analyses de cohortes (par âge, pays, etc.)'
\echo ''
