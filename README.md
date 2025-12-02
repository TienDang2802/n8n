# n8n Docker Compose Setup

This repository provides a production-ready Docker-based setup for running **n8n** with **PostgreSQL**, **Nginx** reverse proxy, and **Let's Encrypt** SSL certificates.

## 📦 Architecture

- **n8n**: Workflow automation platform
- **PostgreSQL**: Database for n8n data persistence
- **Nginx**: Reverse proxy with SSL/TLS termination
- **Certbot**: Automatic SSL certificate renewal

---

## 🚀 Quick Start

### Sử dụng Makefile (Khuyến nghị)

```sh
# Khởi tạo project
make setup

# Chỉnh sửa file .env với cấu hình của bạn
nano .env

# Build và khởi động services
make up

# Xem logs
make logs
```

### Hoặc sử dụng Docker Compose trực tiếp

```sh
# Tạo file .env từ template (xem ENV_VARIABLES.md)
cp env.example .env
# Chỉnh sửa .env file với cấu hình của bạn
nano .env

# Build và khởi động services
docker compose up -d --build

# Xem logs
docker compose logs -f
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
│       └── templates/
│           ├── dev/            # Development templates
│           └── prod/          # Production templates
├── data/                       # Persistent data (created by setup)
├── logs/                       # Application logs (created by setup)
└── cert/                       # SSL certificates (created by setup)
```

---

## 📋 Makefile Commands

Sử dụng `make help` để xem tất cả các lệnh có sẵn:

### Setup & Build
- `make setup` - Khởi tạo project (copy .env, tạo thư mục)
- `make build` - Build Docker images
- `make rebuild` - Rebuild images và khởi động lại

### Service Management
- `make up` hoặc `make start` - Khởi động tất cả services
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
- `make certbot-init` - Khởi tạo SSL certificate (cần set NGINX_HOST và EMAIL trong .env)
- `make certbot-renew` - Renew SSL certificates

### Cleanup
- `make clean` - Xóa containers và networks (giữ volumes)
- `make clean-all` - Xóa tất cả bao gồm volumes (⚠️ DANGER)

### Other
- `make pull` - Pull latest images
- `make update` - Pull và rebuild images

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
  - `EMAIL` - Email for Let's Encrypt notifications

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
```sh
# Xem certbot logs
make logs-certbot

# Manually renew certificate
make certbot-renew

# Initialize certificate (first time)
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

---

## 🔒 Security Best Practices

1. **Change default passwords**: Luôn thay đổi passwords mặc định trong `.env`
2. **Use strong passwords**: Sử dụng passwords mạnh cho PostgreSQL và n8n
3. **SSL/TLS**: Luôn sử dụng HTTPS trong production (`NGINX_ENV=prod`)
4. **Firewall**: Chỉ mở ports 80 và 443, không expose n8n port 5678
5. **Regular updates**: Cập nhật Docker images định kỳ: `make update`
6. **Backup**: Thực hiện backup database thường xuyên: `make backup-db`

---

## 📞 Support

- [n8n Documentation](https://docs.n8n.io)
- [n8n Community Forum](https://community.n8n.io)
- [Docker Compose Documentation](https://docs.docker.com/compose/)

---

## 📄 License

This setup is provided as-is for running n8n with Docker Compose.
