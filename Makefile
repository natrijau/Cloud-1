# Makefile - Cloud-1 Docker Testing
# Usage: make <target>

.PHONY: help build up down stop clean prune logs ps test mariadb wordpress nginx phpmyadmin

DOCKER_DIR = docker
ENV_FILE = $(DOCKER_DIR)/.env

help:
	@echo "Cloud-1 Docker Commands"
	@echo ""
	@echo "Stack:"
	@echo "  make build         Build all images"
	@echo "  make up            Start full stack"
	@echo "  make down          Stop and remove stack"
	@echo "  make stop          Stop containers (keep volumes)"
	@echo "  make clean         Full cleanup (images + volumes)"
	@echo "  make prune         Docker system prune"
	@echo "  make logs          Follow logs"
	@echo "  make ps            Show status"
	@echo "  make test          Run validation tests"
	@echo ""
	@echo "Individual services (for debugging):"
	@echo "  make mariadb       Start only MariaDB"
	@echo "  make wordpress     Start WordPress (needs MariaDB)"
	@echo "  make nginx         Start Nginx (needs WP + PMA)"
	@echo "  make phpmyadmin    Start phpMyAdmin (needs MariaDB)"

build:
	docker build -t cloud1-mariadb $(DOCKER_DIR)/mariadb
	docker build -t cloud1-wordpress $(DOCKER_DIR)/wordpress
	docker build -t cloud1-nginx $(DOCKER_DIR)/nginx
	docker build -t cloud1-phpmyadmin $(DOCKER_DIR)/phpmyadmin

up: $(ENV_FILE) build
	cd $(DOCKER_DIR) && docker compose --env-file .env up -d --build
	@echo "Waiting for services..."
	@sleep 30
	@make ps

down:
	cd $(DOCKER_DIR) && docker compose --env-file .env down -v 2>/dev/null || true

stop:
	cd $(DOCKER_DIR) && docker compose --env-file .env stop 2>/dev/null || true

clean: down
	docker image rm cloud1-mariadb cloud1-wordpress cloud1-nginx cloud1-phpmyadmin 2>/dev/null || true
	docker volume rm docker_db_data docker_wp_data docker_pma_data docker_letsencrypt 2>/dev/null || true
	rm -rf /tmp/cloud1-data 2>/dev/null || true

prune:
	docker system prune -a --volumes -f

logs:
	cd $(DOCKER_DIR) && docker compose --env-file .env logs -f

ps:
	cd $(DOCKER_DIR) && docker compose --env-file .env ps

test: up
	@echo "=== Validation tests ==="
	@cd $(DOCKER_DIR) && \
	docker compose --env-file .env exec -T mariadb mysqladmin ping -h 127.0.0.1 -u wp_user -p$$SQL_PASSWORD --silent && echo "MariaDB: OK" && \
	docker compose --env-file .env exec -T mariadb mysql -u wp_user -p$$SQL_PASSWORD -e "USE wordpress; SHOW TABLES;" | grep -q wp_users && echo "WordPress tables: OK" && \
	curl -k -s -o /dev/null -w "WordPress: %{http_code}\n" https://localhost:8443 | grep -q 200 && echo "WordPress HTTPS: OK" && \
	curl -k -s -o /dev/null -w "phpMyAdmin: %{http_code}\n" https://pma.localhost:8443 | grep -q 200 && echo "phpMyAdmin HTTPS: OK" && \
	echo "=== ALL TESTS PASSED ==="

$(ENV_FILE):
	@printf "SQL_DATABASE=wordpress\nSQL_USER=wp_user\nSQL_PASSWORD=testpass\nSQL_ROOT_PASSWORD=rootpass\nWP_URL=https://localhost:8443\nWP_TITLE=\"Test Cloud-1\"\nWP_ADMIN_LOGIN=admin\nWP_ADMIN_PASSWORD=adminpass\nWP_ADMIN_EMAIL=admin@test.local\nWP_USER_LOGIN=editor\nWP_USER_EMAIL=editor@test.local\nWP_USER_PASSWORD=editorpass\nPMA_BLOWFISH_SECRET=32charsrandomstring123456789012\nDOMAIN_NAME=localhost\n" > $(ENV_FILE)
	mkdir -p /tmp/cloud1-data/{wordpress,mariadb,phpmyadmin,letsencrypt}

# ============================================================
# INDIVIDUAL SERVICES (debugging)
# ============================================================

mariadb: $(ENV_FILE)
	docker build -t cloud1-mariadb $(DOCKER_DIR)/mariadb
	docker rm -f test-mariadb 2>/dev/null || true
	docker run -d --name test-mariadb \
		-e SQL_DATABASE=wordpress \
		-e SQL_USER=wp_user \
		-e SQL_PASSWORD=testpass \
		-e SQL_ROOT_PASSWORD=rootpass \
		-v /tmp/cloud1-data/mariadb:/var/lib/mysql \
		cloud1-mariadb
	@echo "Waiting for MariaDB..."
	@while ! docker exec test-mariadb mysqladmin ping -h 127.0.0.1 -u root -prootpass --silent 2>/dev/null; do sleep 2; done
	@echo "MariaDB ready on port 3306"

wordpress: mariadb
	docker build -t cloud1-wordpress $(DOCKER_DIR)/wordpress
	docker rm -f test-wordpress 2>/dev/null || true
	docker run -d --name test-wordpress \
		-e SQL_DATABASE=wordpress \
		-e SQL_USER=wp_user \
		-e SQL_PASSWORD=testpass \
		-e WP_URL=https://localhost:8443 \
		-e WP_TITLE="Test Cloud-1" \
		-e WP_ADMIN_LOGIN=admin \
		-e WP_ADMIN_PASSWORD=adminpass \
		-e WP_ADMIN_EMAIL=admin@test.local \
		-e WP_USER_LOGIN=editor \
		-e WP_USER_EMAIL=editor@test.local \
		-e WP_USER_PASSWORD=editorpass \
		-v /tmp/cloud1-data/wordpress:/var/www/wordpress \
		--link test-mariadb:mariadb \
		cloud1-wordpress
	@echo "WordPress starting... (check logs with: docker logs -f test-wordpress)"

phpmyadmin: mariadb
	docker build -t cloud1-phpmyadmin $(DOCKER_DIR)/phpmyadmin
	docker rm -f test-phpmyadmin 2>/dev/null || true
	docker run -d --name test-phpmyadmin \
		-e PMA_HOST=mariadb \
		-e PMA_USER=wp_user \
		-e PMA_PASSWORD=testpass \
		-e PMA_BLOWFISH_SECRET=32charsrandomstring123456789012 \
		-v /tmp/cloud1-data/phpmyadmin:/var/www/html \
		--link test-mariadb:mariadb \
		-p 8080:80 \
		cloud1-phpmyadmin
	@echo "phpMyAdmin at http://localhost:8080 (user: wp_user / pass: testpass)"

nginx: wordpress phpmyadmin
	docker build -t cloud1-nginx $(DOCKER_DIR)/nginx
	docker rm -f test-nginx 2>/dev/null || true
	docker run -d --name test-nginx \
		-e DOMAIN_NAME=localhost \
		-v /tmp/cloud1-data/wordpress:/var/www/wordpress \
		-v /tmp/cloud1-data/phpmyadmin:/var/www/phpmyadmin \
		-v /tmp/cloud1-data/letsencrypt:/etc/letsencrypt \
		--link test-wordpress:wordpress \
		--link test-phpmyadmin:phpmyadmin \
		-p 8080:80 -p 8443:443 \
		cloud1-nginx
	@echo "Nginx at https://localhost:8443 and https://pma.localhost:8443"