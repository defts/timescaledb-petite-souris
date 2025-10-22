# Comment la Petite Souris gère ses milliards de dents avec TimescaleDB

## 📋 Vue d'ensemble

Cette présentation de 30 minutes explore TimescaleDB à travers un cas d'usage ludique : le système d'information de la Petite Souris. De la mise en place aux optimisations avancées, avec des démos live et un retour d'expérience production sur 37 milliards de données.

## 🎯 Objectifs

- Comprendre les concepts clés de TimescaleDB (hypertables, chunks, time_bucket)
- Maîtriser les optimisations : compression, continuous aggregates, retention policies
- Découvrir les hyperfunctions exclusives à TimescaleDB
- Partager un retour d'expérience production

## 🏗️ Structure du projet

```
.
├── README.md                          # Ce fichier
├── PRESENTATION.md                    # Plan de présentation et checklist
├── WORKFLOW_GENERATION_DONNEES.md     # Guide génération de données
├── Makefile                           # Commandes simplifiées
├── slides.md                          # Présentation Slidev
├── docker-compose.yml                 # Stack PostgreSQL + TimescaleDB
├── cmd/datagen/                       # Générateur de données en Go
├── internal/generator/                # Logique de génération
└── scripts/
    ├── 01-setup.sql                   # Setup DB + tables
    ├── demo/
    │   ├── 01-hyperfunctions.sql      # Démo hyperfunctions
    │   ├── 02-compression.sql         # Démo compression
    │   ├── 03-caggs.sql               # Démo continuous aggregates
    │   ├── 04-retention.sql           # Démo retention
    │   ├── prep-02-compression.sql    # Préparation compression
    │   └── prep-03-caggs.sql          # Préparation caggs
    └── archives/                      # Anciens scripts de référence
```
