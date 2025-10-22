# ============================================================================
# Makefile pour la présentation TimescaleDB - La Petite Souris
# ============================================================================

# Configuration
DB_HOST = localhost
DB_PORT = 5432
DB_USER = postgres
DB_NAME = petite_souris
DB_PASSWORD = password

# Commandes psql
PSQL = PGPASSWORD=$(DB_PASSWORD) psql -h $(DB_HOST) -p $(DB_PORT) -U $(DB_USER) -d $(DB_NAME)
PSQL_POSTGRES = PGPASSWORD=$(DB_PASSWORD) psql -h $(DB_HOST) -p $(DB_PORT) -U $(DB_USER) -d postgres

# Couleurs
GREEN = \033[0;32m
YELLOW = \033[1;33m
BLUE = \033[0;34m
NC = \033[0m

# ============================================================================
# Aide
# ============================================================================

.PHONY: help
help: ## Afficher l'aide
	@echo "$(BLUE)============================================================================$(NC)"
	@echo "$(BLUE)  TimescaleDB - Présentation La Petite Souris$(NC)"
	@echo "$(BLUE)============================================================================$(NC)"
	@echo ""
	@echo "$(GREEN)🐳 Docker:$(NC)"
	@echo "  $(YELLOW)make start$(NC)          Démarrer TimescaleDB"
	@echo "  $(YELLOW)make stop$(NC)           Arrêter TimescaleDB"
	@echo "  $(YELLOW)make logs$(NC)           Voir les logs"
	@echo ""
	@echo "$(GREEN)🔧 Setup:$(NC)"
	@echo "  $(YELLOW)make setup$(NC)          Setup initial (DB + tables + 1M enfants)"
	@echo ""
	@echo "$(GREEN)📊 Génération de données:$(NC)"
	@echo "  $(YELLOW)make build$(NC)          Compiler le générateur Go"
	@echo "  $(YELLOW)make backfill-historical$(NC) Remplir données historiques (400 jours)"
	@echo "  $(YELLOW)make backfill-delta$(NC) Remplir le delta depuis dernière date"
	@echo "  $(YELLOW)make stream$(NC)         Stream continu (Ctrl+C pour stop)"
	@echo ""
	@echo "$(GREEN)🎤 Présentation:$(NC)"
	@echo "  $(YELLOW)make slides$(NC)         Lancer Slidev"
	@echo ""
	@echo "$(GREEN)🛠️  Utilitaires:$(NC)"
	@echo "  $(YELLOW)make psql$(NC)           Se connecter à psql"
	@echo "  $(YELLOW)make stats$(NC)          Afficher les stats de la base"
	@echo ""
	@echo "$(BLUE)============================================================================$(NC)"

# ============================================================================
# Docker
# ============================================================================

.PHONY: start
start: ## Démarrer TimescaleDB
	@echo "$(GREEN)🚀 Démarrage de TimescaleDB...$(NC)"
	@docker-compose up -d
	@echo "$(GREEN)⏳ Attente que la base soit prête...$(NC)"
	@sleep 5
	@until docker-compose exec -T timescaledb pg_isready -U postgres > /dev/null 2>&1; do \
		sleep 2; \
	done
	@echo "$(GREEN)✅ TimescaleDB est prêt !$(NC)"

.PHONY: stop
stop: ## Arrêter TimescaleDB
	@echo "$(YELLOW)🛑 Arrêt de TimescaleDB...$(NC)"
	@docker-compose stop

.PHONY: logs
logs: ## Voir les logs
	@docker-compose logs -f timescaledb

# ============================================================================
# Setup
# ============================================================================

.PHONY: setup
setup: ## Setup initial (DB + tables + 1M enfants)
	@echo "$(GREEN)🦷 Setup initial (1M enfants)$(NC)"
	@$(PSQL_POSTGRES) -v num_children=1000000 -f scripts/01-setup.sql

# ============================================================================
# Génération de données
# ============================================================================

.PHONY: build
build: ## Compiler le générateur Go
	@echo "$(GREEN)🔨 Compilation du générateur...$(NC)"
	@mkdir -p bin
	@go build -o bin/datagen cmd/datagen/main.go
	@echo "$(GREEN)✅ Binaire compilé dans bin/datagen$(NC)"

.PHONY: backfill-historical
backfill-historical: ## Remplir ~400 jours de données historiques
	@echo "$(GREEN)📅 Backfill historique: ~400 jours$(NC)"
	@go run cmd/datagen/main.go backfill-historical --days 400 --rate 5000 --batch 100

.PHONY: backfill-delta
backfill-delta: ## Remplir le delta depuis dernière date
	@echo "$(GREEN)📅 Backfill delta: remplir depuis dernière date$(NC)"
	@echo "ℹ️  Configuration: 60 pays, 1000000 enfants max"
	@go run cmd/datagen/main.go backfill-delta --rate 5000 --batch 100

.PHONY: stream
stream: ## Stream continu pour démo
	@echo "$(GREEN)📡 Stream de données continu (10 lignes/sec)$(NC)"
	@echo "$(YELLOW)Appuyez sur Ctrl+C pour arrêter$(NC)"
	@go run cmd/datagen/main.go stream --rate 10

# ============================================================================
# Présentation
# ============================================================================

.PHONY: slides
slides: ## Lancer Slidev
	@echo "$(GREEN)🎤 Lancement de Slidev...$(NC)"
	@npm run dev

# ============================================================================
# Utilitaires
# ============================================================================

.PHONY: psql
psql: ## Se connecter à psql
	@echo "$(GREEN)🔌 Connexion à psql...$(NC)"
	@$(PSQL)

.PHONY: stats
stats: ## Afficher les stats de la base
	@echo "$(BLUE)📊 Statistiques de la base:$(NC)"
	@echo ""
	@$(PSQL) -c "SELECT COUNT(*) as total_rows, MIN(collected_at) as oldest, MAX(collected_at) as newest, COUNT(DISTINCT child_id) as unique_children FROM tooth_loss;"
	@echo ""
	@echo "$(BLUE)📦 Taille des données:$(NC)"
	@$(PSQL) -c "SELECT pg_size_pretty(pg_total_relation_size('tooth_loss')) as taille_totale FROM tooth_loss LIMIT 1;"

# ============================================================================
# Default
# ============================================================================

.DEFAULT_GOAL := help
