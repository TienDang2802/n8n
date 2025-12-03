# n8n Docker Compose Setup

This repository provides a production-ready Docker-based setup for running **n8n** with **PostgreSQL**, **Nginx** reverse proxy, and **Let's Encrypt** SSL certificates.

## 📦 Architecture

- **n8n**: Workflow automation platform
- **PostgreSQL**: Database for n8n data persistence
- **Nginx**: Reverse proxy with SSL/TLS termination and automatic reload
- **Certbot**: Automatic SSL certificate renewal (every 12 hours)
- **Auto-reload**: Nginx automatically reloads configuration every 6 hours to pick up certificate changes

---

## 🚀 Quick Start

### Development (Localhost, HTTP only)

For local development without SSL certificates:

```sh
# 1. Initialize project
make setup

# 2. Edit .env file for DEV
nano .env
# Set:
#   NGINX_ENV=dev
#   NGINX_HOST=localhost
#   NGINX_PORT=80
#   N8N_HOST=localhost
#   N8N_PROTOCOL=http

# 3. Start services in DEV mode
make up-dev

# 4. Access n8n at http://localhost
```

### Production (VPS with Domain, HTTPS)

For production deployment with SSL certificates:

```sh
# 1. Initialize project
make setup

# 2. Edit .env file for PROD
nano .env
# Set:
#   NGINX_ENV=prod
#   NGINX_HOST=your-domain.com
#   NGINX_PORT=443
#   N8N_HOST=your-domain.com
#   N8N_PROTOCOL=https
#   SSL_EMAIL=your-email@example.com

# 3. Ensure DNS A record points to your VPS IP
dig your-domain.com

# 4. Start services in PROD mode (HTTP-only initially)
make up-prod

# 5. Initialize SSL certificates
make certbot-init

# 6. Restart nginx to load HTTPS configuration
make restart

# 7. Verify HTTPS is working
curl -I https://your-domain.com
```

### Using Docker Compose directly

```sh
# Set environment variables in .env first
# Then:
docker compose up -d --build
```

---

## 📁 Project Structure

```
.
├── docker-compose.yml          # Docker Compose configuration
├── Makefile                    # Make commands for easy management
├── README.md                   # This file
├── ENV_VARIABLES.md            # Environment variables reference
├── DEPLOYMENT.md               # Deployment guide and optimizations
├── OPTIMIZATION_SUMMARY.md     # Summary of optimizations
├── infrastructure/
│   ├── n8n/
│   │   └── Dockerfile          # n8n custom Dockerfile
│   ├── dbms/
│   │   └── postgres/
│   │       └── Dockerfile      # PostgreSQL Dockerfile
│   └── nginx/
│       ├── Dockerfile          # Nginx Dockerfile
│       ├── nginx.conf          # Nginx main configuration
│       ├── entrypoint.sh       # Nginx entrypoint script
│       ├── 99-autoreload.sh    # Auto-reload script for SSL certs
│       └── templates/
│           ├── dev/            # Development templates (no SSL)
│           └── prod/          # Production templates (with SSL)
├── scripts/
│   └── init-letsencrypt.sh     # Initial SSL certificate setup script
├── data/                       # Persistent data (created by setup)
├── logs/                       # Application logs (created by setup)
└── cert/                       # SSL certificates (created by setup)
│   └── nginx/
│       ├── letsencrypt/        # Let's Encrypt certificates
│       └── certbot/            # Certbot webroot directory
```

---

## 📋 Makefile Commands

Sử dụng `make help` để xem tất cả các lệnh có sẵn:

### Setup & Build
- `make setup` - Khởi tạo project (copy .env, tạo thư mục)
- `make build` - Build Docker images
- `make rebuild` - Rebuild images và khởi động lại

### Service Management
- `make up` hoặc `make start` - Khởi động tất cả services (uses NGINX_ENV from .env)
- `make up-dev` - Khởi động services cho DEV environment (HTTP only, no SSL)
- `make up-prod` - Khởi động services cho PROD environment (HTTPS with SSL)
- `make down` hoặc `make stop` - Dừng services
- `make restart` - Khởi động lại services
- `make ps` hoặc `make status` - Xem trạng thái containers

### Logs
- `make logs` - Xem logs tất cả services
- `make logs-db` - Xem logs database
- `make logs-n8n` - Xem logs n8n
- `make logs-nginx` - Xem logs nginx
- `make logs-certbot` - Xem logs certbot

### Shell Access
- `make shell-db` - Truy cập shell PostgreSQL
- `make shell-n8n` - Truy cập shell n8n
- `make shell-nginx` - Truy cập shell nginx
- `make db-psql` - Truy cập PostgreSQL CLI

### Database Backup & Restore
- `make backup-db` - Backup database
- `make restore-db FILE=backup.sql` - Restore database từ file backup

### SSL Certificate
- `make certbot-init` - Khởi tạo SSL certificate lần đầu (cần set NGINX_HOST và SSL_EMAIL trong .env)
  - Script này sẽ:
    - Request certificate từ Let's Encrypt
    - Generate DH parameters
    - Download Let's Encrypt recommended SSL options
    - Tự động start nginx nếu chưa chạy
- `make certbot-renew` - Renew SSL certificates manually (thường không cần, certbot tự động renew mỗi 12h)

### Cleanup
- `make clean` - Xóa containers và networks (giữ volumes)
- `make clean-all` - Xóa tất cả bao gồm volumes (⚠️ DANGER)

### Other
- `make pull` - Pull latest images
- `make update` - Pull và rebuild images

---

## 🔐 SSL Certificate Setup

### How It Works

The setup automatically handles SSL certificate initialization:

1. **First Start (PROD mode)**: Nginx starts with HTTP-only configuration that allows ACME challenges
2. **After `make certbot-init`**: Certificates are created and nginx automatically switches to HTTPS configuration
3. **Automatic Renewal**: Certbot renews certificates every 12 hours, nginx reloads every 6 hours

### Initial Setup (First Time)

1. **Configure environment variables** in `.env`:
   ```env
   NGINX_ENV=prod
   NGINX_HOST=your-domain.com
   SSL_EMAIL=your-email@example.com
   N8N_PROTOCOL=https
   N8N_HOST=your-domain.com
   ```

2. **Ensure DNS is configured**: Your domain must have an A record pointing to your VPS IP

3. **Start services** (nginx will start with HTTP-only config):
   ```sh
   make up-prod
   ```

4. **Initialize SSL certificates**:
   ```sh
   make certbot-init
   ```
   
   This script will:
   - Verify nginx is running and can serve ACME challenges
   - Request SSL certificate from Let's Encrypt using HTTP-01 challenge
   - Generate DH parameters for enhanced security
   - Download Let's Encrypt recommended SSL configuration

5. **Restart nginx** to load HTTPS configuration:
   ```sh
   make restart
   ```
   
   After restart, nginx will automatically detect the certificates and use the HTTPS configuration.

### Automatic Certificate Renewal

The setup includes automatic certificate renewal:

- **Certbot** renews certificates every 12 hours
- **Nginx auto-reload** runs every 6 hours to pick up certificate changes
- No manual intervention required after initial setup

The auto-reload script (`99-autoreload.sh`) is automatically mounted into the nginx container and runs in the background.

### SSL Configuration

The production nginx template uses Let's Encrypt recommended SSL settings:
- Modern TLS protocols (TLSv1.2, TLSv1.3)
- Strong cipher suites
- OCSP stapling
- Security headers (HSTS, etc.)

Certificates are stored in: `cert/nginx/letsencrypt/`

---

## 📝 Environment Variables

Cần cấu hình các biến môi trường trong file `.env`. Xem chi tiết trong [ENV_VARIABLES.md](ENV_VARIABLES.md).

### Biến môi trường bắt buộc:

- **PostgreSQL**: 
  - `POSTGRES_USER` - Database user
  - `POSTGRES_PASSWORD` - Database password (⚠️ CHANGE THIS!)
  - `POSTGRES_DB` - Database name
  - `POSTGRES_VERSION` - PostgreSQL version (default: alpine)

- **n8n**: 
  - `N8N_USER` - n8n admin username
  - `N8N_PASSWORD` - n8n admin password (⚠️ CHANGE THIS!)
  - `N8N_HOST` - Your domain name
  - `N8N_PROTOCOL` - http or https
  - `N8N_VERSION` - n8n version (optional, default: latest)

- **Nginx**: 
  - `NGINX_ENV` - Environment: `prod` or `dev` (default: prod)
  - `NGINX_HOST` - Your domain name (should match N8N_HOST)
  - `NGINX_PORT` - Port (default: 443 for HTTPS)

- **Paths**: 
  - `DATA_PATH_HOST` - Path for persistent data
  - `NGINX_HOST_LOG_PATH` - Path for nginx logs
  - `CERT_PATH` - Path for SSL certificates

- **SSL**: 
  - `SSL_EMAIL` - Email for Let's Encrypt notifications

### Tạo file .env:

```sh
# Sử dụng Makefile (khuyến nghị)
make setup

# Hoặc tạo thủ công
cp env.example .env
nano .env
```

---

## 🔧 Troubleshooting

### Xem logs để debug
```sh
# Xem tất cả logs
make logs

# Xem logs của service cụ thể
make logs-n8n
make logs-db
make logs-nginx
make logs-certbot
```

### Kiểm tra trạng thái containers
```sh
# Xem trạng thái tất cả containers
make ps
# hoặc
docker compose ps

# Kiểm tra resource usage
docker stats
```

### Restart service cụ thể
```sh
# Restart tất cả services
make restart

# Restart service cụ thể
docker compose restart n8n
docker compose restart db
docker compose restart nginx
```

### Backup database
```sh
# Backup database
make backup-db

# Restore database
make restore-db FILE=backups/backup_20240101_120000.sql
```

### SSL Certificate Issues

#### Certificate không được tạo
```sh
# Kiểm tra nginx đã chạy chưa (cần cho ACME challenge)
make ps

# Kiểm tra domain đã trỏ về server chưa
dig your-domain.com

# Xem certbot logs
make logs-certbot

# Thử lại init
make certbot-init
```

#### Certificate không tự động renew
```sh
# Kiểm tra certbot container đang chạy
docker ps | grep certbot

# Xem certbot logs
make logs-certbot

# Manually renew certificate
make certbot-renew

# Kiểm tra nginx auto-reload
docker logs n8n_nginx | grep "reloaded"
```

#### Nginx không load certificate
```sh
# Kiểm tra certificate files tồn tại
ls -la cert/nginx/letsencrypt/live/your-domain.com/

# Test nginx configuration
docker exec n8n_nginx nginx -t

# Manually reload nginx
docker exec n8n_nginx nginx -s reload

# Kiểm tra nginx logs
make logs-nginx
```

#### Initialize certificate (first time)
```sh
# Đảm bảo .env có NGINX_HOST và SSL_EMAIL
# Đảm bảo nginx đang chạy
make up

# Initialize certificate
make certbot-init
```

### Service không start
1. Kiểm tra logs: `make logs`
2. Kiểm tra `.env` file có đầy đủ biến không
3. Kiểm tra ports 80 và 443 có bị chiếm không: `sudo lsof -i :80 -i :443`
4. Kiểm tra disk space: `df -h`
5. Kiểm tra Docker daemon: `docker info`

### n8n không kết nối được database
1. Kiểm tra database đã start: `make logs-db`
2. Kiểm tra credentials trong `.env`
3. Kiểm tra network: `docker network inspect n8n_n8n_net`

---

## 📚 Documentation

- **[ENV_VARIABLES.md](ENV_VARIABLES.md)** - Chi tiết về environment variables

## 🔄 How SSL Auto-Renewal Works

This setup implements automatic SSL certificate renewal based on the approach described in:
[Setup SSL with Certbot + Nginx in a Dockerized App](https://dev.to/marrouchi/the-challenge-about-ssl-in-docker-containers-no-one-talks-about-32gh)

### Components:

1. **Certbot Service**: Runs continuously, renews certificates every 12 hours
2. **Nginx Auto-Reload Script**: Runs in background, reloads nginx every 6 hours
3. **Let's Encrypt Recommended Config**: Uses official SSL configuration files

### Flow:

```
Certbot renews cert → Certificates updated → Nginx auto-reload picks up changes → SSL active
```

This ensures certificates are always up-to-date without manual intervention.

---

## 🔒 Security Best Practices

1. **Change default passwords**: Luôn thay đổi passwords mặc định trong `.env`
2. **Use strong passwords**: Sử dụng passwords mạnh cho PostgreSQL và n8n
3. **SSL/TLS**: 
   - Luôn sử dụng HTTPS trong production (`NGINX_ENV=prod`)
   - Certificates tự động renew mỗi 12 giờ
   - Nginx tự động reload để áp dụng certificates mới
4. **Firewall**: Chỉ mở ports 80 và 443, không expose n8n port 5678
5. **Regular updates**: Cập nhật Docker images định kỳ: `make update`
6. **Backup**: Thực hiện backup database thường xuyên: `make backup-db`
7. **Domain validation**: Đảm bảo domain đã trỏ về server trước khi chạy `certbot-init`

---

## 📞 Support

- [n8n Documentation](https://docs.n8n.io)
- [n8n Community Forum](https://community.n8n.io)
- [Docker Compose Documentation](https://docs.docker.com/compose/)

---

## 📄 License

This setup is provided as-is for running n8n with Docker Compose.
