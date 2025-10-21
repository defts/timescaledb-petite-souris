# ============================================================================
# Makefile pour la présentation TimescaleDB - La Petite Souris
# ============================================================================
# Usage:
#   make help           Afficher l'aide
#   make start          Démarrer la stack Docker
#   make stop           Arrêter la stack Docker
#   make restart        Redémarrer proprement
#   make reset          Tout supprimer et recommencer
#   make 01             Exécuter le script 01-setup.sql
#   make 02             Exécuter le script 02-generate-data.sql
#   make 03             Exécuter le script 03-queries.sql
#   make 04             Exécuter le script 04-compression.sql
#   make 05             Exécuter le script 05-retention.sql
#   make 06             Exécuter le script 06-continuous-aggregates.sql
#   make all            Exécuter tous les scripts (01 à 06)
#   make demo           Setup complet pour la démo (start + 01 + 02)
#   make slides         Lancer Slidev
#   make psql           Se connecter à psql
# ============================================================================

# Configuration
DB_HOST = localhost
DB_PORT = 5432
DB_USER = postgres
DB_NAME = petite_souris
DB_PASSWORD = password

# Commande psql (pour se connecter à la base petite_souris)
PSQL = PGPASSWORD=$(DB_PASSWORD) psql -h $(DB_HOST) -p $(DB_PORT) -U $(DB_USER) -d $(DB_NAME)
PSQL_FILE = $(PSQL) -f

# Commande psql pour se connecter à la base postgres (pour le script 01 qui crée la base)
PSQL_POSTGRES = PGPASSWORD=$(DB_PASSWORD) psql -h $(DB_HOST) -p $(DB_PORT) -U $(DB_USER) -d postgres

# Couleurs pour l'output
RED = \033[0;31m
GREEN = \033[0;32m
YELLOW = \033[1;33m
BLUE = \033[0;34m
NC = \033[0m # No Color

# ============================================================================
# Commandes principales
# ============================================================================

.PHONY: help
help: ## Afficher l'aide
	@echo "$(BLUE)============================================================================$(NC)"
	@echo "$(BLUE)  Makefile - Présentation TimescaleDB (La Petite Souris)$(NC)"
	@echo "$(BLUE)============================================================================$(NC)"
	@echo ""
	@echo "$(GREEN)Commandes Docker:$(NC)"
	@echo "  $(YELLOW)make start$(NC)          Démarrer la stack Docker"
	@echo "  $(YELLOW)make stop$(NC)           Arrêter la stack Docker"
	@echo "  $(YELLOW)make restart$(NC)        Redémarrer la stack"
	@echo "  $(YELLOW)make reset$(NC)          Tout supprimer et recommencer à zéro"
	@echo "  $(YELLOW)make logs$(NC)           Voir les logs de TimescaleDB"
	@echo "  $(YELLOW)make status$(NC)         Voir le statut des containers"
	@echo ""
	@echo "$(GREEN)Scripts SQL:$(NC)"
	@echo "  $(YELLOW)make 01$(NC)             Setup initial (extension + hypertable)"
	@echo "  $(YELLOW)make 02$(NC)             Génération de données (~100M lignes)"
	@echo "  $(YELLOW)make 03$(NC)             Requêtes temporelles (time_bucket)"
	@echo "  $(YELLOW)make 04$(NC)             Compression des données"
	@echo "  $(YELLOW)make 05$(NC)             Retention policies"
	@echo "  $(YELLOW)make 06$(NC)             Continuous aggregates"
	@echo "  $(YELLOW)make all$(NC)            Exécuter tous les scripts (01 à 06)"
	@echo ""
	@echo "$(GREEN)Préparation démo:$(NC)"
	@echo "  $(YELLOW)make demo$(NC)           Setup complet (start + 01 + 02)"
	@echo "  $(YELLOW)make quick-demo$(NC)     Demo rapide avec moins de données"
	@echo ""
	@echo "$(GREEN)Présentation:$(NC)"
	@echo "  $(YELLOW)make slides$(NC)         Lancer Slidev en mode dev"
	@echo "  $(YELLOW)make slides-build$(NC)   Build Slidev pour production"
	@echo ""
	@echo "$(GREEN)Utilitaires:$(NC)"
	@echo "  $(YELLOW)make psql$(NC)           Se connecter à psql"
	@echo "  $(YELLOW)make stats$(NC)          Afficher les stats de la base"
	@echo "  $(YELLOW)make clean-db$(NC)       Nettoyer la base (DROP table)"
	@echo ""
	@echo "$(BLUE)============================================================================$(NC)"

.PHONY: start
start: ## Démarrer la stack Docker
	@echo "$(GREEN)🚀 Démarrage de TimescaleDB...$(NC)"
	@docker-compose up -d
	@echo "$(GREEN)⏳ Attente que la base soit prête...$(NC)"
	@sleep 5
	@until docker-compose exec -T timescaledb pg_isready -U postgres > /dev/null 2>&1; do \
		echo "$(YELLOW)⏳ En attente de PostgreSQL...$(NC)"; \
		sleep 2; \
	done
	@echo "$(GREEN)✅ TimescaleDB est prêt !$(NC)"
	@echo ""
	@$(MAKE) status

.PHONY: stop
stop: ## Arrêter la stack Docker
	@echo "$(YELLOW)🛑 Arrêt de la stack...$(NC)"
	@docker-compose stop
	@echo "$(GREEN)✅ Stack arrêtée$(NC)"

.PHONY: restart
restart: stop start ## Redémarrer la stack

.PHONY: reset
reset: ## Tout supprimer et recommencer à zéro
	@echo "$(RED)⚠️  ATTENTION: Cette commande va TOUT supprimer !$(NC)"
	@echo "$(RED)Appuyez sur Ctrl+C pour annuler, ou Entrée pour continuer...$(NC)"
	@read confirm
	@echo "$(YELLOW)🗑️  Suppression complète...$(NC)"
	@docker-compose down -v
	@echo "$(GREEN)✅ Tout a été supprimé$(NC)"
	@echo "$(BLUE)💡 Utilisez 'make demo' pour recommencer$(NC)"

.PHONY: logs
logs: ## Voir les logs de TimescaleDB
	@docker-compose logs -f timescaledb

.PHONY: status
status: ## Statut des containers
	@echo "$(BLUE)📊 Statut des containers:$(NC)"
	@docker-compose ps

# ============================================================================
# Scripts SQL
# ============================================================================

.PHONY: 01
01: ## Script 01: Setup initial (crée la base petite_souris)
	@echo "$(GREEN)🦷 === Script 01: Setup initial ===$(NC)"
	@$(PSQL_POSTGRES) -f scripts/01-setup.sql
	@echo ""

.PHONY: 02
02: ## Script 02: Génération de données
	@echo "$(GREEN)🦷 === Script 02: Génération de données ===$(NC)"
	@echo "$(YELLOW)⏱️  Cela peut prendre 2-3 minutes...$(NC)"
	@$(PSQL_FILE) scripts/02-generate-data.sql
	@echo ""

.PHONY: 03
03: ## Script 03: Requêtes temporelles
	@echo "$(GREEN)🦷 === Script 03: Requêtes temporelles ===$(NC)"
	@$(PSQL_FILE) scripts/03-queries.sql
	@echo ""

.PHONY: 04
04: ## Script 04: Compression
	@echo "$(GREEN)🦷 === Script 04: Compression ===$(NC)"
	@$(PSQL_FILE) scripts/04-compression.sql
	@echo ""

.PHONY: 05
05: ## Script 05: Retention policies
	@echo "$(GREEN)🦷 === Script 05: Retention policies ===$(NC)"
	@$(PSQL_FILE) scripts/05-retention.sql
	@echo ""

.PHONY: 06
06: ## Script 06: Continuous aggregates
	@echo "$(GREEN)🦷 === Script 06: Continuous aggregates ===$(NC)"
	@$(PSQL_FILE) scripts/06-continuous-aggregates.sql
	@echo ""

.PHONY: all
all: 01 02 03 04 05 06 ## Exécuter tous les scripts

# ============================================================================
# Préparation démo
# ============================================================================

.PHONY: demo
demo: ## Setup complet pour la démo (start + 01 + 02)
	@echo "$(BLUE)============================================================================$(NC)"
	@echo "$(BLUE)  Préparation complète de la démo$(NC)"
	@echo "$(BLUE)============================================================================$(NC)"
	@echo ""
	@$(MAKE) start
	@echo ""
	@$(MAKE) 01
	@echo ""
	@$(MAKE) 02
	@echo ""
	@echo "$(GREEN)🎉 Démo prête ! Vous pouvez maintenant:$(NC)"
	@echo "  - $(YELLOW)make 03$(NC) pour les requêtes"
	@echo "  - $(YELLOW)make 04$(NC) pour la compression"
	@echo "  - $(YELLOW)make 05$(NC) pour la retention"
	@echo "  - $(YELLOW)make 06$(NC) pour les continuous aggregates"
	@echo "  - $(YELLOW)make slides$(NC) pour lancer la présentation"
	@echo ""

.PHONY: quick-demo
quick-demo: ## Demo rapide avec moins de données (pour tests)
	@echo "$(BLUE)🚀 Quick demo avec moins de données$(NC)"
	@$(MAKE) start
	@$(MAKE) 01
	@echo "$(YELLOW)📝 Génération de données réduites...$(NC)"
	@echo "INSERT INTO tooth_loss SELECT time, (random() * 2000000000)::int, (random() * 20 + 1)::int, (ARRAY['FR', 'DE', 'ES', 'IT', 'US', 'UK'])[ceil(random()*6)], 'City_' || (random() * 1000)::int, (random() * 10 + 0.5)::decimal(10,2), CASE WHEN random() < 0.7 THEN 'cash' WHEN random() < 0.9 THEN 'coin' ELSE 'gift' END FROM generate_series(NOW() - INTERVAL '6 months', NOW(), INTERVAL '5 seconds') AS time;" | $(PSQL)
	@echo "$(GREEN)✅ Quick demo prête !$(NC)"

# ============================================================================
# Présentation Slidev
# ============================================================================

.PHONY: slides
slides: ## Lancer Slidev en mode dev
	@echo "$(GREEN)🎤 Lancement de Slidev...$(NC)"
	@npm run dev

.PHONY: slides-build
slides-build: ## Build Slidev pour production
	@echo "$(GREEN)📦 Build de Slidev...$(NC)"
	@npm run build

.PHONY: slides-export
slides-export: ## Exporter les slides en PDF
	@echo "$(GREEN)📄 Export PDF...$(NC)"
	@npm run export

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
	@echo "SELECT COUNT(*) as total_rows, pg_size_pretty(pg_total_relation_size('tooth_loss')) as size, MIN(time)::date as oldest, MAX(time)::date as newest FROM tooth_loss;" | $(PSQL) -t 2>/dev/null || echo "$(YELLOW)⚠️  La table tooth_loss n'existe pas encore. Utilisez 'make 01' d'abord.$(NC)"
	@echo ""
	@echo "$(BLUE)📦 Chunks:$(NC)"
	@echo "SELECT COUNT(*) as chunks FROM timescaledb_information.chunks WHERE hypertable_name = 'tooth_loss';" | $(PSQL) -t 2>/dev/null || echo ""

.PHONY: clean-db
clean-db: ## Nettoyer la base (DROP table)
	@echo "$(RED)🗑️  Suppression de la table tooth_loss...$(NC)"
	@echo "DROP TABLE IF EXISTS tooth_loss CASCADE;" | $(PSQL)
	@echo "$(GREEN)✅ Table supprimée$(NC)"
	@echo "$(BLUE)💡 Utilisez 'make 01' pour recréer$(NC)"

.PHONY: check
check: ## Vérifier que tout est prêt
	@echo "$(BLUE)🔍 Vérification de l'environnement:$(NC)"
	@echo ""
	@echo -n "$(YELLOW)Docker: $(NC)"
	@command -v docker >/dev/null 2>&1 && echo "$(GREEN)✅$(NC)" || echo "$(RED)❌$(NC)"
	@echo -n "$(YELLOW)Docker Compose: $(NC)"
	@command -v docker-compose >/dev/null 2>&1 && echo "$(GREEN)✅$(NC)" || echo "$(RED)❌$(NC)"
	@echo -n "$(YELLOW)psql: $(NC)"
	@command -v psql >/dev/null 2>&1 && echo "$(GREEN)✅$(NC)" || echo "$(RED)❌$(NC)"
	@echo -n "$(YELLOW)Node.js: $(NC)"
	@command -v node >/dev/null 2>&1 && echo "$(GREEN)✅$(NC)" || echo "$(RED)❌$(NC)"
	@echo -n "$(YELLOW)npm: $(NC)"
	@command -v npm >/dev/null 2>&1 && echo "$(GREEN)✅$(NC)" || echo "$(RED)❌$(NC)"
	@echo ""
	@echo -n "$(YELLOW)TimescaleDB running: $(NC)"
	@docker-compose ps | grep -q "Up" && echo "$(GREEN)✅$(NC)" || echo "$(RED)❌ (utilisez 'make start')$(NC)"

# ============================================================================
# Default
# ============================================================================

.DEFAULT_GOAL := help
