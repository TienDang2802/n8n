# Environment Variables Reference

File này mô tả tất cả các biến môi trường cần thiết cho project.

## Tạo file .env

```bash
cp env.example .env
# hoặc
make setup
```

## Biến môi trường bắt buộc

### PostgreSQL
```env
POSTGRES_VERSION=alpine          # PostgreSQL version (alpine recommended)
POSTGRES_USER=n8n                # Database user
POSTGRES_PASSWORD=your_password  # Database password (CHANGE THIS!)
POSTGRES_DB=n8n                  # Database name
```

### n8n
```env
N8N_VERSION=latest                # n8n version (optional, defaults to latest)
N8N_USER=admin                    # n8n admin username
N8N_PASSWORD=your_password       # n8n admin password (CHANGE THIS!)
N8N_HOST=your-domain.com         # Your domain name
N8N_PROTOCOL=https                # http or https
```

### Nginx
```env
NGINX_ENV=prod                    # Environment: prod or dev
NGINX_HOST=your-domain.com        # Your domain name (same as N8N_HOST)
NGINX_PORT=443                    # Port (443 for HTTPS, 80 for HTTP in dev)
```

### Paths
```env
DATA_PATH_HOST=./data             # Path for persistent data (relative or absolute)
NGINX_HOST_LOG_PATH=./logs/nginx  # Path for nginx logs
CERT_PATH=./cert                  # Path for SSL certificates
```

### SSL Certificate (Let's Encrypt)
```env
EMAIL=your-email@example.com      # Email for Let's Encrypt notifications
```

## Biến môi trường tùy chọn

### n8n Performance (đã được set trong docker-compose.yml)
```env
N8N_METRICS=true
EXECUTIONS_PROCESS=main
EXECUTIONS_DATA_SAVE_ON_ERROR=all
EXECUTIONS_DATA_SAVE_ON_SUCCESS=all
EXECUTIONS_DATA_SAVE_MANUAL_EXECUTIONS=true
```

### PostgreSQL Performance Tuning
Thêm vào `.env` nếu cần tối ưu thêm (không bắt buộc):
```env
POSTGRES_SHARED_BUFFERS=256MB
POSTGRES_EFFECTIVE_CACHE_SIZE=1GB
POSTGRES_MAINTENANCE_WORK_MEM=64MB
POSTGRES_CHECKPOINT_COMPLETION_TARGET=0.9
POSTGRES_WAL_BUFFERS=16MB
POSTGRES_DEFAULT_STATISTICS_TARGET=100
POSTGRES_RANDOM_PAGE_COST=1.1
POSTGRES_EFFECTIVE_IO_CONCURRENCY=200
POSTGRES_WORK_MEM=4MB
POSTGRES_MIN_WAL_SIZE=1GB
POSTGRES_MAX_WAL_SIZE=4GB
```

## Ví dụ file .env hoàn chỉnh

```env
# PostgreSQL
POSTGRES_VERSION=alpine
POSTGRES_USER=n8n
POSTGRES_PASSWORD=ChangeMe123!StrongPassword
POSTGRES_DB=n8n

# n8n
N8N_VERSION=latest
N8N_USER=admin
N8N_PASSWORD=ChangeMe123!StrongPassword
N8N_HOST=automation.example.com
N8N_PROTOCOL=https

# Nginx
NGINX_ENV=prod
NGINX_HOST=automation.example.com
NGINX_PORT=443

# Paths
DATA_PATH_HOST=./data
NGINX_HOST_LOG_PATH=./logs/nginx
CERT_PATH=./cert

# SSL
EMAIL=admin@example.com
```

## Lưu ý

1. **Security**: Luôn thay đổi passwords mặc định
2. **Paths**: Có thể dùng relative paths (./data) hoặc absolute paths (/var/lib/n8n/data)
3. **Domain**: `N8N_HOST` và `NGINX_HOST` nên giống nhau
4. **Protocol**: Production nên dùng `https`, dev có thể dùng `http`
5. **Email**: Cần email hợp lệ cho Let's Encrypt certificate

## Validation

Sau khi tạo `.env`, kiểm tra:
```bash
# Kiểm tra syntax
docker compose config

# Hoặc test build
make build
```

