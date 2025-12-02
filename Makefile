.PHONY: help setup build up down restart logs ps clean shell-db shell-n8n shell-nginx certbot-init certbot-renew status health

# Colors for output
GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
WHITE  := $(shell tput -Txterm setaf 7)
RESET  := $(shell tput -Txterm sgr0)

# Default values
COMPOSE_FILE := docker-compose.yml
ENV_FILE := .env

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
	docker compose -f $(COMPOSE_FILE) build

up: ## Khởi động tất cả services (detached mode)
	@echo "$(GREEN)Starting services...$(RESET)"
	docker compose -f $(COMPOSE_FILE) up -d
	@echo "$(GREEN)Services started!$(RESET)"
	@echo "$(YELLOW)Run 'make logs' to view logs$(RESET)"

start: up ## Alias cho up

down: ## Dừng và xóa containers
	@echo "$(YELLOW)Stopping services...$(RESET)"
	docker compose -f $(COMPOSE_FILE) down

stop: down ## Alias cho down

restart: ## Khởi động lại tất cả services
	@echo "$(GREEN)Restarting services...$(RESET)"
	docker compose -f $(COMPOSE_FILE) restart

logs: ## Xem logs của tất cả services (follow mode)
	docker compose -f $(COMPOSE_FILE) logs -f

logs-db: ## Xem logs của database
	docker compose -f $(COMPOSE_FILE) logs -f db

logs-n8n: ## Xem logs của n8n
	docker compose -f $(COMPOSE_FILE) logs -f n8n

logs-nginx: ## Xem logs của nginx
	docker compose -f $(COMPOSE_FILE) logs -f nginx

logs-certbot: ## Xem logs của certbot
	docker compose -f $(COMPOSE_FILE) logs -f certbot

ps: ## Hiển thị trạng thái các containers
	docker compose -f $(COMPOSE_FILE) ps

status: ps ## Alias cho ps

health: ## Kiểm tra health của các services
	@echo "$(GREEN)Checking service health...$(RESET)"
	@echo "\n$(YELLOW)Container Status:$(RESET)"
	@docker compose -f $(COMPOSE_FILE) ps
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
		. $(ENV_FILE); \
		docker exec -it n8n_postgres psql -U $$POSTGRES_USER -d $$POSTGRES_DB; \
	else \
		echo "$(YELLOW)⚠ .env file not found$(RESET)"; \
		docker exec -it n8n_postgres psql -U postgres; \
	fi

clean: ## Xóa containers, networks (giữ volumes)
	@echo "$(YELLOW)Cleaning up containers and networks...$(RESET)"
	docker compose -f $(COMPOSE_FILE) down
	@echo "$(GREEN)Clean completed (volumes preserved)$(RESET)"

clean-all: ## Xóa tất cả: containers, networks, volumes (⚠️ DANGER: mất dữ liệu)
	@echo "$(YELLOW)⚠ WARNING: This will remove all containers, networks, and volumes!$(RESET)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker compose -f $(COMPOSE_FILE) down -v; \
		echo "$(GREEN)All cleaned up$(RESET)"; \
	else \
		echo "$(YELLOW)Cancelled$(RESET)"; \
	fi

pull: ## Pull latest images
	@echo "$(GREEN)Pulling latest images...$(RESET)"
	docker compose -f $(COMPOSE_FILE) pull

rebuild: ## Rebuild images và khởi động lại services
	@echo "$(GREEN)Rebuilding and restarting services...$(RESET)"
	docker compose -f $(COMPOSE_FILE) up -d --build --force-recreate

certbot-init: ## Khởi tạo SSL certificate với certbot (cần set DOMAIN và EMAIL trong .env)
	@if [ ! -f $(ENV_FILE) ]; then \
		echo "$(YELLOW)⚠ .env file not found. Run 'make setup' first$(RESET)"; \
		exit 1; \
	fi
	@. $(ENV_FILE); \
	if [ -z "$$NGINX_HOST" ] || [ -z "$$EMAIL" ]; then \
		echo "$(YELLOW)⚠ Please set NGINX_HOST and EMAIL in .env file$(RESET)"; \
		exit 1; \
	fi; \
	echo "$(GREEN)Initializing SSL certificate for $$NGINX_HOST...$(RESET)"; \
	docker run --rm -it \
		-v $$(pwd)/cert/nginx/letsencrypt:/etc/letsencrypt \
		-v $$(pwd)/cert/nginx/certbot:/var/www/certbot \
		certbot/certbot certonly \
		--webroot \
		--webroot-path=/var/www/certbot \
		--email $$EMAIL \
		--agree-tos \
		--no-eff-email \
		-d $$NGINX_HOST

certbot-renew: ## Renew SSL certificates manually
	@echo "$(GREEN)Renewing SSL certificates...$(RESET)"
	docker compose -f $(COMPOSE_FILE) exec certbot certbot renew

backup-db: ## Backup PostgreSQL database
	@if [ ! -f $(ENV_FILE) ]; then \
		echo "$(YELLOW)⚠ .env file not found$(RESET)"; \
		exit 1; \
	fi
	@. $(ENV_FILE); \
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
	@. $(ENV_FILE); \
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



