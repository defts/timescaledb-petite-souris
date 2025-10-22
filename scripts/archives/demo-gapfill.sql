-- ============================================================================
-- DÉMO GAPFILL : Comparaison AVANT/APRÈS avec Window Function
-- ============================================================================
-- Cette démo montre :
-- 1. Le problème : des créneaux de 30 min manquants (trous dans les données)
-- 2. La solution TimescaleDB : time_bucket_gapfill() remplit les trous
-- 3. Bonus : Window function (cumul) qui fonctionne sur série complète
--
-- Données : France 🇫🇷 le 15 octobre 2024 (24 heures = 48 créneaux de 30 min)
-- ============================================================================

\echo '🇫🇷 === DÉMO GAPFILL sur la France (15 octobre 2024) ==='
\echo ''

-- ============================================================================
-- 😱 PostgreSQL STANDARD : Grouper par 30 minutes = HORRIBLE
-- ============================================================================

\echo '😱 PostgreSQL STANDARD : Comment grouper par 30 minutes sans time_bucket ?'
\echo ''
\echo 'Option : Conversion EPOCH + division + floor + reconversion...'
\echo ''

SELECT
    to_timestamp(floor((extract('epoch' from collected_at) / 1800)) * 1800) AS period, -- Période de 30 minutes
    COUNT(*) as teeth_count
FROM tooth_loss
WHERE collected_at >= '2024-10-15' AND collected_at < '2024-10-16'
  AND country_code = 'FR'
GROUP BY period
ORDER BY period ASC;

\echo ''
\echo '⚠️  C''est ILLISIBLE, COMPLEXE, et peu performant !'
\echo '⚠️  Et ça ne fonctionne que pour des intervalles en secondes (pas "1 month" par ex.)'
\echo ''

-- ============================================================================
-- 😊 TimescaleDB : time_bucket = SIMPLE
-- ============================================================================

\echo '😊 TimescaleDB : time_bucket() simplifie TOUT !'
\echo ''

SELECT
    time_bucket('30 minutes', collected_at) AS period, -- Fini les date_trunc / EXTRACT !
    COUNT(*) as teeth_count
FROM tooth_loss
WHERE collected_at >= '2024-10-15' AND collected_at < '2024-10-16'
  AND country_code = 'FR'
GROUP BY period
ORDER BY period ASC;

\echo ''
\echo '✅ Simple, lisible, performant'
\echo '✅ Fonctionne avec n''importe quel intervalle : ''6 hours'', ''90 minutes'', ''15 days''...'
\echo ''
\echo '❌ MAIS : Seulement ~40 lignes au lieu de 48 attendues'
\echo '❌ Il manque : 02:00, 10:30, 11:30, 12:00, 13:00, 17:30, 20:00, 20:30...'
\echo ''

\echo ''
\echo '⚠️  Problème : Impossible de faire un cumul propre avec des trous !'
\echo '⚠️  Les graphiques auront des discontinuités visuelles'
\echo ''

-- ============================================================================
-- ✅ SOLUTION : Avec gapfill + window function = série complète avec cumul
-- ============================================================================

\echo '✅ AVEC gapfill : TOUS les créneaux apparaissent (48 lignes)'
\echo ''
\echo 'Bonus : Window function (cumul) fonctionne parfaitement !'
\echo ''

SELECT
    time_bucket_gapfill('30 minutes', collected_at) AS period,
    COUNT(*) as teeth_count,
    SUM(COUNT(*)) OVER (ORDER BY time_bucket_gapfill('30 minutes', collected_at)) as cumulative_teeth
FROM tooth_loss
WHERE collected_at >= '2024-10-15' AND collected_at < '2024-10-16'
  AND country_code = 'FR'
GROUP BY period
ORDER BY period ASC;

\echo ''
\echo '💡 Notez :'
\echo '   - 48 lignes (exactement 24h × 2 créneaux/heure)'
\echo '   - teeth_count = 0 pour les créneaux vides (02:00, 10:30, etc.)'
\echo '   - cumulative_teeth continue de progresser même sur les trous !'
\echo ''
\echo '🔥 Différence clé avec PostgreSQL standard :'
\echo '   PostgreSQL : time_bucket() → trous dans les données'
\echo '   TimescaleDB : time_bucket_gapfill() → série temporelle complète'
\echo ''
\echo '🎯 Cas d''usage :'
\echo '   • Dashboards temps réel sans discontinuités visuelles'
\echo '   • Window functions (cumul, moyenne mobile, etc.)'
\echo '   • Machine Learning (features complètes sans NULL)'
\echo '   • Détection d''anomalies (identifier les périodes sans activité)'
\echo ''
