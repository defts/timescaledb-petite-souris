-- ============================================================================
-- Script 01: Setup initial de TimescaleDB
-- ============================================================================
-- Ce script crée l'extension TimescaleDB, la table tooth_loss et la transforme
-- en hypertable pour le partitionnement automatique.
--
-- Usage: psql -h localhost -U postgres -d postgres -f scripts/01-setup.sql
-- ============================================================================

\echo '🦷 === Setup TimescaleDB pour la Petite Souris ==='
\echo ''

-- Activer l'extension TimescaleDB
\echo '📦 Activation de l\'extension TimescaleDB...'
CREATE EXTENSION IF NOT EXISTS timescaledb;

\echo '✅ Extension TimescaleDB activée'
\echo ''

-- Créer la table tooth_loss
\echo '🏗️  Création de la table tooth_loss...'
CREATE TABLE IF NOT EXISTS tooth_loss (
    time            TIMESTAMPTZ NOT NULL,  -- Timestamp de perte de dent
    child_id        INTEGER,               -- ID de l'enfant
    tooth_number    INTEGER,               -- Numéro de la dent (1-20)
    country         TEXT,                  -- Code pays (ISO 3166-1 alpha-2)
    city            TEXT,                  -- Ville
    price           DECIMAL(10,2),         -- Prix payé par la souris
    payment_method  TEXT                   -- Méthode de paiement (cash, coin, gift)
);

\echo '✅ Table tooth_loss créée'
\echo ''

-- Transformer la table en hypertable
-- Les données seront automatiquement partitionnées en chunks de 7 jours
\echo '⚡ Transformation en hypertable (partitionnement automatique)...'
SELECT create_hypertable('tooth_loss', 'time', if_not_exists => TRUE);

\echo '✅ Hypertable créée avec succès !'
\echo ''

-- Créer des index pour optimiser les requêtes
\echo '🔍 Création des index...'
CREATE INDEX IF NOT EXISTS idx_tooth_loss_country_time
    ON tooth_loss (country, time DESC);

CREATE INDEX IF NOT EXISTS idx_tooth_loss_city_time
    ON tooth_loss (city, time DESC);

CREATE INDEX IF NOT EXISTS idx_tooth_loss_child
    ON tooth_loss (child_id, time DESC);

\echo '✅ Index créés'
\echo ''

-- Afficher les informations sur la hypertable
\echo '📊 Informations sur la hypertable:'
SELECT * FROM timescaledb_information.hypertables
WHERE hypertable_name = 'tooth_loss';

\echo ''
\echo '🎉 Setup terminé ! Vous pouvez maintenant générer des données avec 02-generate-data.sql'
\echo ''
