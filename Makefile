.PHONY: help setup build up down restart logs ps clean shell-db shell-n8n shell-nginx certbot-init certbot-renew status health

# Colors for output
GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
WHITE  := $(shell tput -Txterm setaf 7)
RESET  := $(shell tput -Txterm sgr0)

# Default values
COMPOSE_FILE := docker-compose.yml
ENV_FILE := .env

# Detect Docker Compose command (support both 'docker compose' and 'docker-compose')
# Try 'docker compose' first (Docker Compose V2), fallback to 'docker-compose' (V1)
DOCKER_COMPOSE := $(shell docker compose version >/dev/null 2>&1 && echo "docker compose" || echo "docker-compose")

help: ## Hiển thị danh sách các lệnh có sẵn
	@echo "$(GREEN)Available commands:$(RESET)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-20s$(RESET) %s\n", $$1, $$2}'

setup: ## Khởi tạo project: copy .env.example, tạo thư mục cần thiết
	@echo "$(GREEN)Setting up project...$(RESET)"
	@if [ ! -f $(ENV_FILE) ]; then \
		if [ -f .env.example ]; then \
			cp .env.example $(ENV_FILE); \
			echo "$(GREEN)✓ Created .env from .env.example$(RESET)"; \
			echo "$(YELLOW)⚠ Please edit .env file with your configuration$(RESET)"; \
		else \
			echo "$(YELLOW)⚠ .env.example not found. Creating empty .env file$(RESET)"; \
			touch $(ENV_FILE); \
		fi; \
	else \
		echo "$(YELLOW)⚠ .env file already exists$(RESET)"; \
	fi
	@mkdir -p data/postgres data/n8n logs/nginx cert/nginx/letsencrypt cert/nginx/certbot
	@echo "$(GREEN)✓ Created necessary directories$(RESET)"
	@echo "$(GREEN)Setup completed!$(RESET)"

build: ## Build Docker images
	@echo "$(GREEN)Building Docker images...$(RESET)"
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) build

up: ## Khởi động tất cả services (detached mode) - uses NGINX_ENV from .env
	@echo "$(GREEN)Starting services...$(RESET)"
	@if [ -f $(ENV_FILE) ]; then \
		set -a; \
		. $(ENV_FILE); \
		set +a; \
		echo "$(YELLOW)Using NGINX_ENV=$${NGINX_ENV:-prod}$(RESET)"; \
	fi
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) up -d
	@echo "$(GREEN)Services started!$(RESET)"
	@echo "$(YELLOW)Run 'make logs' to view logs$(RESET)"

up-dev: ## Khởi động services cho DEV environment (HTTP only, no SSL)
	@echo "$(GREEN)Starting services in DEV mode (HTTP only)...$(RESET)"
	@if [ -f $(ENV_FILE) ]; then \
		cp $(ENV_FILE) $(ENV_FILE).bak; \
		sed -i.bak 's/^NGINX_ENV=.*/NGINX_ENV=dev/' $(ENV_FILE) 2>/dev/null || \
		sed -i '' 's/^NGINX_ENV=.*/NGINX_ENV=dev/' $(ENV_FILE) 2>/dev/null || \
		echo "NGINX_ENV=dev" >> $(ENV_FILE); \
		rm -f $(ENV_FILE).bak; \
	fi
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) up -d
	@echo "$(GREEN)✓ Services started in DEV mode$(RESET)"
	@echo "$(YELLOW)Run 'make logs' to view logs$(RESET)"
	@echo "$(YELLOW)Access n8n at: http://localhost$(RESET)"

up-prod: ## Khởi động services cho PROD environment (HTTPS with SSL)
	@echo "$(GREEN)Starting services in PROD mode (HTTPS)...$(RESET)"
	@if [ -f $(ENV_FILE) ]; then \
		cp $(ENV_FILE) $(ENV_FILE).bak; \
		sed -i.bak 's/^NGINX_ENV=.*/NGINX_ENV=prod/' $(ENV_FILE) 2>/dev/null || \
		sed -i '' 's/^NGINX_ENV=.*/NGINX_ENV=prod/' $(ENV_FILE) 2>/dev/null || \
		echo "NGINX_ENV=prod" >> $(ENV_FILE); \
		rm -f $(ENV_FILE).bak; \
	fi
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) up -d
	@echo "$(GREEN)✓ Services started in PROD mode$(RESET)"
	@echo "$(YELLOW)Note: If this is first time, run 'make certbot-init' after DNS is configured$(RESET)"
	@echo "$(YELLOW)Run 'make logs' to view logs$(RESET)"

start: up ## Alias cho up

down: ## Dừng và xóa containers
	@echo "$(YELLOW)Stopping services...$(RESET)"
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) down

stop: down ## Alias cho down

restart: ## Khởi động lại tất cả services
	@echo "$(GREEN)Restarting services...$(RESET)"
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) restart

logs: ## Xem logs của tất cả services (follow mode)
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) logs -f

logs-db: ## Xem logs của database
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) logs -f db

logs-n8n: ## Xem logs của n8n
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) logs -f n8n

logs-nginx: ## Xem logs của nginx
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) logs -f nginx

logs-certbot: ## Xem logs của certbot
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) logs -f certbot

ps: ## Hiển thị trạng thái các containers
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) ps

status: ps ## Alias cho ps

health: ## Kiểm tra health của các services
	@echo "$(GREEN)Checking service health...$(RESET)"
	@echo "\n$(YELLOW)Container Status:$(RESET)"
	@$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) ps
	@echo "\n$(YELLOW)Network Status:$(RESET)"
	@docker network ls | grep n8n_net || echo "Network not found"
	@echo "\n$(YELLOW)Volume Status:$(RESET)"
	@docker volume ls | grep -E "(postgres|n8n)" || echo "No volumes found"

shell-db: ## Truy cập shell của PostgreSQL container
	docker exec -it n8n_postgres /bin/bash || docker exec -it n8n_postgres /bin/sh

shell-n8n: ## Truy cập shell của n8n container
	docker exec -it n8n /bin/sh

shell-nginx: ## Truy cập shell của nginx container
	docker exec -it n8n_nginx /bin/sh

db-psql: ## Truy cập PostgreSQL CLI
	@if [ -f $(ENV_FILE) ]; then \
		set -a; \
		. $(ENV_FILE); \
		set +a; \
		docker exec -it n8n_postgres psql -U $$POSTGRES_USER -d $$POSTGRES_DB; \
	else \
		echo "$(YELLOW)⚠ .env file not found$(RESET)"; \
		docker exec -it n8n_postgres psql -U postgres; \
	fi

clean: ## Xóa containers, networks (giữ volumes)
	@echo "$(YELLOW)Cleaning up containers and networks...$(RESET)"
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) down
	@echo "$(GREEN)Clean completed (volumes preserved)$(RESET)"

clean-all: ## Xóa tất cả: containers, networks, volumes (⚠️ DANGER: mất dữ liệu)
	@echo "$(YELLOW)⚠ WARNING: This will remove all containers, networks, and volumes!$(RESET)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) down -v; \
		echo "$(GREEN)All cleaned up$(RESET)"; \
	else \
		echo "$(YELLOW)Cancelled$(RESET)"; \
	fi

pull: ## Pull latest images
	@echo "$(GREEN)Pulling latest images...$(RESET)"
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) pull

rebuild: ## Rebuild images và khởi động lại services
	@echo "$(GREEN)Rebuilding and restarting services...$(RESET)"
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) up -d --build --force-recreate

certbot-init: ## Khởi tạo SSL certificate với certbot (cần set NGINX_HOST và SSL_EMAIL trong .env)
	@if [ ! -f $(ENV_FILE) ]; then \
		echo "$(YELLOW)⚠ .env file not found. Run 'make setup' first$(RESET)"; \
		exit 1; \
	fi
	@bash scripts/init-letsencrypt.sh

certbot-diagnose: ## Chạy diagnostics để kiểm tra cấu hình SSL (troubleshooting)
	@bash -c ' \
	echo "$(GREEN)========================================$(RESET)"; \
	echo "$(GREEN)SSL Certificate Diagnostics$(RESET)"; \
	echo "$(GREEN)========================================$(RESET)"; \
	echo ""; \
	NGINX_HOST_VAL=""; \
	if [ -f $(ENV_FILE) ]; then \
		while IFS= read -r line || [ -n "$$line" ]; do \
			if echo "$$line" | grep -q "^NGINX_HOST=" && ! echo "$$line" | grep -q "^#"; then \
				NGINX_HOST_VAL=$$(echo "$$line" | cut -d "=" -f2- | tr -d "\"'"'"'"); \
				break; \
			fi; \
		done < $(ENV_FILE); \
	fi; \
	echo "$(YELLOW)1. Checking nginx container...$(RESET)"; \
	if docker ps --format "{{.Names}}" | grep -q "^n8n_nginx$$"; then \
		echo "$(GREEN)✓ Nginx container is running$(RESET)"; \
		NGINX_RUNNING=1; \
	else \
		echo "$(RED)✗ Nginx container is NOT running$(RESET)"; \
		echo "   Run: make up-prod"; \
		NGINX_RUNNING=0; \
	fi; \
	echo ""; \
	echo "$(YELLOW)2. Checking port 80 binding...$(RESET)"; \
	if [ "$$NGINX_RUNNING" = "1" ]; then \
		if docker exec n8n_nginx netstat -tlnp 2>/dev/null | grep -q ":80 " || \
		   docker exec n8n_nginx ss -tlnp 2>/dev/null | grep -q ":80 "; then \
			echo "$(GREEN)✓ Nginx is listening on port 80$(RESET)"; \
		else \
			echo "$(RED)✗ Nginx is NOT listening on port 80$(RESET)"; \
		fi; \
	else \
		echo "$(YELLOW)⚠ Cannot check (nginx container not running)$(RESET)"; \
	fi; \
	echo ""; \
	echo "$(YELLOW)3. Checking firewall (ufw)...$(RESET)"; \
	if command -v ufw >/dev/null 2>&1; then \
		if sudo ufw status 2>/dev/null | grep -q "80/tcp"; then \
			echo "$(GREEN)✓ Port 80 is allowed in ufw$(RESET)"; \
		else \
			echo "$(YELLOW)⚠ Port 80 might not be allowed in ufw$(RESET)"; \
			echo "   Run: sudo ufw allow 80/tcp"; \
		fi; \
	else \
		echo "$(YELLOW)⚠ ufw not found, check your firewall manually$(RESET)"; \
	fi; \
	echo ""; \
	echo "$(YELLOW)4. Checking DNS...$(RESET)"; \
	SERVER_IP=$$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || echo "unknown"); \
	echo "   Server IP: $$SERVER_IP"; \
	if [ -n "$$NGINX_HOST_VAL" ]; then \
		echo "   Domain: $$NGINX_HOST_VAL"; \
		echo "   Run: dig $$NGINX_HOST_VAL to verify DNS"; \
	else \
		if [ -f $(ENV_FILE) ]; then \
			echo "   Domain: $(YELLOW)⚠ NGINX_HOST not set in .env$(RESET)"; \
		else \
			echo "   Domain: $(YELLOW)⚠ .env file not found$(RESET)"; \
			echo "   Run: make setup"; \
		fi; \
	fi; \
	echo ""; \
	echo "$(YELLOW)5. Testing ACME challenge endpoint...$(RESET)"; \
	if [ -n "$$NGINX_HOST_VAL" ]; then \
		if curl -s --max-time 5 "http://$$NGINX_HOST_VAL/.well-known/acme-challenge/test" >/dev/null 2>&1; then \
			echo "$(GREEN)✓ Endpoint is accessible from internet$(RESET)"; \
		else \
			echo "$(RED)✗ Endpoint is NOT accessible from internet$(RESET)"; \
			echo "   This is likely the cause of the certificate failure"; \
			echo "   Common causes: firewall, DNS, or port 80 not accessible"; \
		fi; \
	else \
		echo "$(YELLOW)⚠ Cannot test (NGINX_HOST not available)$(RESET)"; \
	fi; \
	echo ""; \
	echo "$(YELLOW)6. Checking nginx configuration...$(RESET)"; \
	if [ "$$NGINX_RUNNING" = "1" ]; then \
		if docker exec n8n_nginx nginx -t 2>/dev/null; then \
			echo "$(GREEN)✓ Nginx configuration is valid$(RESET)"; \
		else \
			echo "$(RED)✗ Nginx configuration has errors$(RESET)"; \
			echo "   Run: make logs-nginx"; \
		fi; \
	else \
		echo "$(YELLOW)⚠ Cannot check (nginx container not running)$(RESET)"; \
	fi; \
	echo ""; \
	echo "$(GREEN)========================================$(RESET)"; \
	echo "For more details, check: make logs-nginx"'

certbot-renew: ## Renew SSL certificates manually
	@echo "$(GREEN)Renewing SSL certificates...$(RESET)"
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) exec certbot certbot renew

backup-db: ## Backup PostgreSQL database
	@if [ ! -f $(ENV_FILE) ]; then \
		echo "$(YELLOW)⚠ .env file not found$(RESET)"; \
		exit 1; \
	fi
	@set -a; \
	. $(ENV_FILE); \
	set +a; \
	BACKUP_FILE="backup_$$(date +%Y%m%d_%H%M%S).sql"; \
	echo "$(GREEN)Backing up database to $$BACKUP_FILE...$(RESET)"; \
	mkdir -p backups; \
	docker exec n8n_postgres pg_dump -U $$POSTGRES_USER $$POSTGRES_DB > backups/$$BACKUP_FILE; \
	echo "$(GREEN)✓ Backup saved to backups/$$BACKUP_FILE$(RESET)"

restore-db: ## Restore PostgreSQL database (usage: make restore-db FILE=backup.sql)
	@if [ ! -f $(ENV_FILE) ]; then \
		echo "$(YELLOW)⚠ .env file not found$(RESET)"; \
		exit 1; \
	fi
	@if [ -z "$(FILE)" ]; then \
		echo "$(YELLOW)⚠ Please specify backup file: make restore-db FILE=backup.sql$(RESET)"; \
		exit 1; \
	fi
	@if [ ! -f "$(FILE)" ]; then \
		echo "$(YELLOW)⚠ Backup file $(FILE) not found$(RESET)"; \
		exit 1; \
	fi
	@set -a; \
	. $(ENV_FILE); \
	set +a; \
	echo "$(YELLOW)⚠ WARNING: This will overwrite the current database!$(RESET)"; \
	read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		echo "$(GREEN)Restoring database from $(FILE)...$(RESET)"; \
		docker exec -i n8n_postgres psql -U $$POSTGRES_USER -d $$POSTGRES_DB < $(FILE); \
		echo "$(GREEN)✓ Database restored$(RESET)"; \
	else \
		echo "$(YELLOW)Cancelled$(RESET)"; \
	fi

update: pull rebuild ## Pull latest images và rebuild

.DEFAULT_GOAL := help



