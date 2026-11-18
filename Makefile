# Makefile - Cloud-1 Docker Testing (CORRIGE)
# Usage: make <target>

.PHONY: help build up down stop clean prune logs ps test mariadb-logs wp-shell db-shell nginx-logs pma-logs

DOCKER_DIR = docker
ENV_FILE = $(DOCKER_DIR)/.env
COMPOSE = cd $(DOCKER_DIR) && docker compose --env-file .env

help:
	@echo "Cloud-1 Docker Commands"
	@echo ""
	@echo "Stack:"
	@echo "  make build         Build all images (via Compose)"
	@echo "  make up            Start full stack"
	@echo "  make down          Stop and remove stack (keep volumes)"
	@echo "  make stop          Stop containers (keep volumes)"
	@echo "  make clean         Full cleanup (images + volumes)"
	@echo "  make prune         Docker system prune"
	@echo "  make logs          Follow logs"
	@echo "  make ps            Show status"
	@echo "  make test          Run validation tests"
	@echo ""
	@echo "Debug individual services:"
	@echo "  make mariadb-logs  Logs MariaDB"
	@echo "  make wp-shell      Shell dans WordPress"
	@echo "  make db-shell      Shell MySQL dans MariaDB"
	@echo "  make nginx-logs    Logs Nginx"
	@echo "  make pma-logs      Logs phpMyAdmin"

# Build UNIQUEMENT via Compose (noms coherents: dodocker pscker-mariadb, etc.)
build:
	$(COMPOSE) build

# Up utilise les images deja buildees (pas de --build)
up: $(ENV_FILE)
	$(COMPOSE) up -d
	@echo "Waiting for services..."
	@sleep 15
	@make ps

down:
	$(COMPOSE) down -v 2>/dev/null || true

stop:
	$(COMPOSE) stop 2>/dev/null || true

clean: down
	$(COMPOSE) down --rmi all -v 2>/dev/null || true
	docker volume rm docker_db_data docker_wp_data docker_pma_data docker_letsencrypt 2>/dev/null || true

prune:
	docker system prune -a --volumes -f

logs:
	$(COMPOSE) logs -f

ps:
	$(COMPOSE) ps

$(ENV_FILE):
	@printf "SQL_DATABASE=wordpress\nSQL_USER=wp_user\nSQL_PASSWORD=testpass\nSQL_ROOT_PASSWORD=rootpass\nWP_URL=https://localhost:8443\nWP_TITLE=\"Test Cloud-1\"\nWP_ADMIN_LOGIN=admin\nWP_ADMIN_PASSWORD=adminpass\nWP_ADMIN_EMAIL=admin@test.local\nWP_USER_LOGIN=editor\nWP_USER_EMAIL=editor@test.local\nWP_USER_PASSWORD=editorpass\nPMA_BLOWFISH_SECRET=32charsrandomstring123456789012\nDOMAIN_NAME=localhost\n" > $(ENV_FILE)

# ============================================================
# DEBUG INDIVIDUEL (via Compose, pas docker run standalone)
# ============================================================

mariadb-logs:
	$(COMPOSE) logs -f mariadb

wp-shell:
	$(COMPOSE) exec wordpress bash

db-shell:
	$(COMPOSE) exec mariadb mysql wordpress -u root -p$$SQL_ROOT_PASSWORD

nginx-logs:
	$(COMPOSE) logs -f nginx
