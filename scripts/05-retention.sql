-- ============================================================================
-- Script 05: Retention Policies (Politiques de rétention)
-- ============================================================================
-- Ce script démontre comment configurer la suppression automatique
-- des données anciennes avec TimescaleDB.
--
-- Usage: psql -h localhost -U postgres -d postgres -f scripts/05-retention.sql
-- ============================================================================

\echo '🦷 === Retention Policies avec TimescaleDB ==='
\echo ''

-- ============================================================================
-- Étape 1: État actuel des données
-- ============================================================================
\echo '📊 === État actuel des données ==='
\echo ''

SELECT
    COUNT(*) as total_rows,
    pg_size_pretty(pg_total_relation_size('tooth_loss')) as total_size,
    MIN(time)::date as oldest_data,
    MAX(time)::date as newest_data,
    AGE(MAX(time), MIN(time)) as data_span
FROM tooth_loss;

\echo ''
\echo '📦 Distribution des chunks par période:'
SELECT
    CASE
        WHEN range_end > NOW() - INTERVAL '7 days' THEN '0-7 jours (récent)'
        WHEN range_end > NOW() - INTERVAL '1 month' THEN '7j-1 mois'
        WHEN range_end > NOW() - INTERVAL '6 months' THEN '1-6 mois'
        WHEN range_end > NOW() - INTERVAL '1 year' THEN '6-12 mois'
        WHEN range_end > NOW() - INTERVAL '2 years' THEN '1-2 ans'
        ELSE '> 2 ans (à supprimer)'
    END as age_range,
    COUNT(*) as chunk_count,
    pg_size_pretty(SUM(
        pg_total_relation_size(format('%I.%I', chunk_schema, chunk_name))
    )) as total_size
FROM timescaledb_information.chunks
WHERE hypertable_name = 'tooth_loss'
GROUP BY age_range
ORDER BY MIN(range_end) DESC;

-- ============================================================================
-- Étape 2: Identifier les chunks qui seront supprimés
-- ============================================================================
\echo ''
\echo '🗑️  === Chunks qui seront supprimés (> 3 ans) ==='
\echo ''

SELECT
    chunk_name,
    range_start::date as start_date,
    range_end::date as end_date,
    pg_size_pretty(
        pg_total_relation_size(format('%I.%I', chunk_schema, chunk_name))
    ) as size,
    AGE(NOW(), range_end) as age
FROM timescaledb_information.chunks
WHERE hypertable_name = 'tooth_loss'
  AND range_end < NOW() - INTERVAL '3 years'
ORDER BY range_end;

\echo ''
\echo '📊 Résumé des données à supprimer:'
SELECT
    COUNT(*) as chunks_to_delete,
    pg_size_pretty(SUM(
        pg_total_relation_size(format('%I.%I', chunk_schema, chunk_name))
    )) as space_to_free
FROM timescaledb_information.chunks
WHERE hypertable_name = 'tooth_loss'
  AND range_end < NOW() - INTERVAL '3 years';

-- ============================================================================
-- Étape 3: Configuration de la retention policy
-- ============================================================================
\echo ''
\echo '⚙️  === Configuration de la retention policy ==='
\echo ''

-- Créer une policy pour supprimer automatiquement les données > 3 ans
-- Note: Ajustez l'intervalle selon vos besoins
SELECT add_retention_policy('tooth_loss', INTERVAL '3 years');

\echo ''
\echo '✅ Retention policy créée !'
\echo '   - Les chunks de plus de 3 ans seront automatiquement supprimés'
\echo '   - Exécution: toutes les semaines par défaut'
\echo ''

-- ============================================================================
-- Étape 4: Vérifier la policy créée
-- ============================================================================
\echo '📋 === Jobs de retention configurés ==='
\echo ''

SELECT
    job_id,
    schedule_interval,
    config,
    next_start
FROM timescaledb_information.jobs
WHERE proc_name = 'policy_retention';

-- ============================================================================
-- Étape 5: Exécuter manuellement la policy (pour la démo)
-- ============================================================================
\echo ''
\echo '🔄 === Exécution manuelle de la retention policy ==='
\echo ''

-- Récupérer le job_id de la policy
\set job_id (SELECT job_id FROM timescaledb_information.jobs WHERE proc_name = 'policy_retention' AND hypertable_name = 'tooth_loss' LIMIT 1)

-- Note: Décommentez la ligne suivante pour exécuter manuellement
-- CALL run_job(:job_id);

\echo '💡 Pour exécuter manuellement la policy:'
\echo '   SELECT job_id FROM timescaledb_information.jobs WHERE proc_name = ''policy_retention'';'
\echo '   CALL run_job(<job_id>);'
\echo ''

-- ============================================================================
-- Étape 6: Simuler une suppression manuelle (alternative)
-- ============================================================================
\echo '📝 === Suppression manuelle de chunks (alternative à la policy) ==='
\echo ''
\echo '💡 Si vous voulez supprimer manuellement un chunk spécifique:'
\echo '   SELECT drop_chunks(''tooth_loss'', older_than => INTERVAL ''3 years'');'
\echo ''
\echo 'Ou pour supprimer avant une date précise:'
\echo '   SELECT drop_chunks(''tooth_loss'', older_than => ''2022-01-01''::timestamptz);'
\echo ''

-- Afficher combien de lignes seraient supprimées
\echo '📊 Estimation du nombre de lignes à supprimer:'
SELECT COUNT(*) as rows_to_delete
FROM tooth_loss
WHERE time < NOW() - INTERVAL '3 years';

-- ============================================================================
-- Étape 7: État après retention (si exécutée)
-- ============================================================================
\echo ''
\echo '📊 === État actuel après configuration ==='
\echo ''

SELECT
    COUNT(*) as total_rows,
    pg_size_pretty(pg_total_relation_size('tooth_loss')) as total_size,
    MIN(time)::date as oldest_data,
    MAX(time)::date as newest_data
FROM tooth_loss;

\echo ''
\echo '📦 Chunks restants:'
SELECT COUNT(*) as remaining_chunks
FROM timescaledb_information.chunks
WHERE hypertable_name = 'tooth_loss';

-- ============================================================================
-- Étape 8: Modifier ou supprimer une retention policy
-- ============================================================================
\echo ''
\echo '🔧 === Gestion des retention policies ==='
\echo ''
\echo '💡 Pour modifier la policy (changer la période de rétention):'
\echo '   -- Supprimer l''ancienne'
\echo '   SELECT remove_retention_policy(''tooth_loss'');'
\echo '   '
\echo '   -- Créer une nouvelle avec une période différente'
\echo '   SELECT add_retention_policy(''tooth_loss'', INTERVAL ''2 years'');'
\echo ''
\echo '💡 Pour désactiver temporairement:'
\echo '   SELECT alter_job(<job_id>, scheduled => false);'
\echo ''
\echo '💡 Pour réactiver:'
\echo '   SELECT alter_job(<job_id>, scheduled => true);'
\echo ''
\echo '💡 Pour supprimer complètement la policy:'
\echo '   SELECT remove_retention_policy(''tooth_loss'');'
\echo ''

-- ============================================================================
-- Étape 9: Combiner compression + retention
-- ============================================================================
\echo ''
\echo '🎯 === Stratégie recommandée: Compression + Retention ==='
\echo ''
\echo '1. Données récentes (0-7j):    NON compressées, modifiables'
\echo '2. Données intermédiaires (7j-3 ans): COMPRESSÉES, lecture seule'
\echo '3. Données anciennes (> 3 ans):       SUPPRIMÉES automatiquement'
\echo ''
\echo 'Configuration type:'
\echo '   -- Compression après 7 jours'
\echo '   SELECT add_compression_policy(''tooth_loss'', INTERVAL ''7 days'');'
\echo '   '
\echo '   -- Retention à 3 ans'
\echo '   SELECT add_retention_policy(''tooth_loss'', INTERVAL ''3 years'');'
\echo ''

-- ============================================================================
-- Monitoring de la retention
-- ============================================================================
\echo '📊 === Monitoring des policies ==='
\echo ''

SELECT
    job_id,
    proc_name,
    hypertable_name,
    scheduled,
    schedule_interval,
    next_start
FROM timescaledb_information.jobs
WHERE hypertable_name = 'tooth_loss'
ORDER BY proc_name;

\echo ''
\echo '🎉 Configuration de retention terminée !'
\echo ''
\echo '📊 Points clés à retenir:'
\echo '   ✅ Retention policy configurée (3 ans)'
\echo '   ✅ Suppression automatique des vieux chunks'
\echo '   ✅ Libération d''espace disque automatique'
\echo '   ✅ Maintenance simplifiée (zéro intervention)'
\echo '   ✅ Combinable avec la compression'
\echo ''

-- ============================================================================
-- NOTES POUR LA PRÉSENTATION
-- ============================================================================
-- 1. Expliquer pourquoi on ne garde pas tout éternellement
-- 2. Montrer la simplicité de la configuration (1 ligne SQL)
-- 3. Insister sur l'aspect automatique (set and forget)
-- 4. Montrer la combinaison avec compression:
--    - 0-7j: données chaudes (non compressées)
--    - 7j-3ans: données tièdes (compressées)
--    - >3ans: supprimées
-- 5. Mentionner la possibilité d'archiver avant suppression
-- ============================================================================
