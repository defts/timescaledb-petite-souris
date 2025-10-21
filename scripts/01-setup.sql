-- ============================================================================
-- Script 01: Setup initial de TimescaleDB
-- ============================================================================
-- Ce script crée la base de données petite_souris, l'extension TimescaleDB,
-- les tables et transforme tooth_loss en hypertable.
--
-- Usage: psql -h localhost -U postgres -d postgres -f scripts/01-setup.sql
--
-- Configuration :
--   Modifier NUM_CHILDREN ci-dessous pour ajuster le nombre d'enfants générés
--   - Test rapide    : 100
--   - Test moyen     : 100000 (100k)
--   - Production     : 50000000 (50M)
-- ============================================================================

\set NUM_CHILDREN 100

\echo '🦷 === Setup TimescaleDB pour la Petite Souris ==='
\echo ''
\echo '⚙️  Configuration: ':NUM_CHILDREN' enfants seront générés'
\echo ''

-- Créer la base de données
\echo '🗄️  Création de la base de données petite_souris...'
DROP DATABASE IF EXISTS petite_souris;
CREATE DATABASE petite_souris;

\echo '✅ Base de données petite_souris créée'
\echo ''

-- Se connecter à la nouvelle base
\c petite_souris

-- Activer l'extension TimescaleDB
\echo '📦 Activation de l\'extension TimescaleDB...'
CREATE EXTENSION IF NOT EXISTS timescaledb;

\echo '✅ Extension TimescaleDB activée'
\echo ''

-- Créer la table countries
\echo '🌍 Création de la table countries...'
CREATE TABLE IF NOT EXISTS countries (
    code TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    continent TEXT
);

INSERT INTO countries (code, name, continent) VALUES
-- Europe
('FR', 'France', 'Europe'),
('DE', 'Germany', 'Europe'),
('ES', 'Spain', 'Europe'),
('IT', 'Italy', 'Europe'),
('UK', 'United Kingdom', 'Europe'),
('PL', 'Poland', 'Europe'),
('RO', 'Romania', 'Europe'),
('NL', 'Netherlands', 'Europe'),
('BE', 'Belgium', 'Europe'),
('GR', 'Greece', 'Europe'),
('PT', 'Portugal', 'Europe'),
('SE', 'Sweden', 'Europe'),
('AT', 'Austria', 'Europe'),
('CH', 'Switzerland', 'Europe'),
('NO', 'Norway', 'Europe'),
('DK', 'Denmark', 'Europe'),
('FI', 'Finland', 'Europe'),
('IE', 'Ireland', 'Europe'),
-- Amérique du Nord
('US', 'United States', 'North America'),
('CA', 'Canada', 'North America'),
('MX', 'Mexico', 'North America'),
-- Amérique du Sud
('BR', 'Brazil', 'South America'),
('AR', 'Argentina', 'South America'),
('CO', 'Colombia', 'South America'),
('CL', 'Chile', 'South America'),
('PE', 'Peru', 'South America'),
('VE', 'Venezuela', 'South America'),
-- Asie
('CN', 'China', 'Asia'),
('IN', 'India', 'Asia'),
('JP', 'Japan', 'Asia'),
('KR', 'South Korea', 'Asia'),
('ID', 'Indonesia', 'Asia'),
('PH', 'Philippines', 'Asia'),
('VN', 'Vietnam', 'Asia'),
('TH', 'Thailand', 'Asia'),
('MY', 'Malaysia', 'Asia'),
('SG', 'Singapore', 'Asia'),
('TR', 'Turkey', 'Asia'),
('SA', 'Saudi Arabia', 'Asia'),
('AE', 'United Arab Emirates', 'Asia'),
-- Afrique
('EG', 'Egypt', 'Africa'),
('ZA', 'South Africa', 'Africa'),
('NG', 'Nigeria', 'Africa'),
('KE', 'Kenya', 'Africa'),
('MA', 'Morocco', 'Africa'),
('TN', 'Tunisia', 'Africa'),
('DZ', 'Algeria', 'Africa'),
('ET', 'Ethiopia', 'Africa'),
('GH', 'Ghana', 'Africa'),
('UG', 'Uganda', 'Africa'),
-- Océanie
('AU', 'Australia', 'Oceania'),
('NZ', 'New Zealand', 'Oceania'),
('PG', 'Papua New Guinea', 'Oceania'),
('FJ', 'Fiji', 'Oceania'),
-- Amérique Centrale et Caraïbes
('CR', 'Costa Rica', 'Central America'),
('PA', 'Panama', 'Central America'),
('GT', 'Guatemala', 'Central America'),
('JM', 'Jamaica', 'Caribbean'),
('CU', 'Cuba', 'Caribbean'),
('DO', 'Dominican Republic', 'Caribbean')
ON CONFLICT (code) DO NOTHING;

\echo '✅ Table countries créée avec 60 pays'
\echo ''

-- Créer la table teeth
\echo '🦷 Création de la table teeth...'
CREATE TABLE IF NOT EXISTS teeth (
    tooth_number INTEGER PRIMARY KEY,
    tooth_name TEXT NOT NULL,
    typical_age INTEGER  -- Age moyen de perte
);

INSERT INTO teeth (tooth_number, tooth_name, typical_age) VALUES
-- Dents de lait inférieures
(1, 'Incisive centrale inférieure gauche', 6),
(2, 'Incisive centrale inférieure droite', 6),
(3, 'Incisive latérale inférieure gauche', 7),
(4, 'Incisive latérale inférieure droite', 7),
(5, 'Canine inférieure gauche', 9),
(6, 'Canine inférieure droite', 9),
(7, 'Première molaire inférieure gauche', 10),
(8, 'Première molaire inférieure droite', 10),
(9, 'Deuxième molaire inférieure gauche', 11),
(10, 'Deuxième molaire inférieure droite', 11),
-- Dents de lait supérieures
(11, 'Incisive centrale supérieure gauche', 7),
(12, 'Incisive centrale supérieure droite', 7),
(13, 'Incisive latérale supérieure gauche', 8),
(14, 'Incisive latérale supérieure droite', 8),
(15, 'Canine supérieure gauche', 10),
(16, 'Canine supérieure droite', 10),
(17, 'Première molaire supérieure gauche', 11),
(18, 'Première molaire supérieure droite', 11),
(19, 'Deuxième molaire supérieure gauche', 12),
(20, 'Deuxième molaire supérieure droite', 12)
ON CONFLICT (tooth_number) DO NOTHING;

\echo '✅ Table teeth créée avec 20 dents de lait'
\echo ''

-- Créer la table children
\echo '👶 Création de la table children...'
CREATE TABLE IF NOT EXISTS children (
    child_id BIGINT PRIMARY KEY,
    birth_date DATE,  -- Pour calculer l'âge
    country_code TEXT REFERENCES countries(code)
);

\echo '✅ Table children créée'
\echo '⏳ Génération des enfants...'

-- Générer les enfants avec des pays aléatoires
WITH country_array AS (
    SELECT array_agg(code) AS codes FROM countries
)
INSERT INTO children (child_id, birth_date, country_code)
SELECT
    child_id,
    -- Enfants nés entre il y a 18 ans et il y a 6 ans (âge de perte des dents de lait)
    (CURRENT_DATE - INTERVAL '18 years') + (random() * 365 * 12)::INTEGER * INTERVAL '1 day' AS birth_date,
    -- Choisir un pays aléatoire parmi les 60
    codes[1 + floor(random() * array_length(codes, 1))::INTEGER] AS country_code
FROM generate_series(1, :NUM_CHILDREN) AS child_id, country_array;

\echo '✅ Enfants générés'
\echo ''

-- Créer la table tooth_loss
\echo '🏗️  Création de la table tooth_loss...'
CREATE TABLE IF NOT EXISTS tooth_loss (
    time            TIMESTAMPTZ NOT NULL,  -- Timestamp de perte de dent
    child_id        BIGINT REFERENCES children(child_id),  -- ID de l'enfant (FK vers children)
    tooth_number    INTEGER REFERENCES teeth(tooth_number),  -- Numéro de la dent (FK vers teeth)
    country_code    TEXT REFERENCES countries(code),  -- Code pays (FK vers countries)
    city            TEXT,                  -- Ville
    price           DECIMAL(4,2) CHECK (price >= 0)  -- Prix payé (0.00 à 99.99)
    -- Note: Pas de UNIQUE (child_id, tooth_number) car incompatible avec les hypertables
    -- TimescaleDB exige que toute contrainte UNIQUE inclue la colonne de partitionnement (time)
    -- Dans une vraie application, cette contrainte serait gérée au niveau applicatif
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
    ON tooth_loss (country_code, time DESC);

CREATE INDEX IF NOT EXISTS idx_tooth_loss_city_time
    ON tooth_loss (city, time DESC);

CREATE INDEX IF NOT EXISTS idx_tooth_loss_child
    ON tooth_loss (child_id, time DESC);

CREATE INDEX IF NOT EXISTS idx_tooth_loss_tooth
    ON tooth_loss (tooth_number, time DESC);

\echo '✅ Index créés'
\echo ''

-- Afficher les informations sur la hypertable
\echo '📊 Informations sur la hypertable:'
SELECT * FROM timescaledb_information.hypertables
WHERE hypertable_name = 'tooth_loss';

\echo ''
\echo '🎉 Setup terminé ! Vous pouvez maintenant générer des données avec 02-generate-data.sql'
\echo ''
