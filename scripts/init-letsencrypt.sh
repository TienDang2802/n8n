#!/bin/bash
# Initialize Let's Encrypt SSL certificates
# This script should be run once to generate the initial SSL certificates
# Based on: https://dev.to/marrouchi/the-challenge-about-ssl-in-docker-containers-no-one-talks-about-32gh

set -e

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="${PROJECT_ROOT}/.env"

# Detect Docker Compose command (support both 'docker compose' and 'docker-compose')
DOCKER_COMPOSE=$(docker compose version >/dev/null 2>&1 && echo "docker compose" || echo "docker-compose")

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Let's Encrypt SSL Certificate Setup${NC}"
echo -e "${BLUE}========================================${NC}"

# Load environment variables
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}Error: .env file not found at $ENV_FILE${NC}"
    echo "Please run 'make setup' first or create .env file manually"
    exit 1
fi

set -a
source "$ENV_FILE"
set +a

# Validate required variables
if [ -z "$NGINX_HOST" ]; then
    echo -e "${RED}Error: NGINX_HOST is not set in .env file${NC}"
    exit 1
fi

if [ -z "$SSL_EMAIL" ]; then
    echo -e "${RED}Error: SSL_EMAIL is not set in .env file${NC}"
    exit 1
fi

# Validate NGINX_ENV is prod
if [ "${NGINX_ENV:-prod}" != "prod" ]; then
    echo -e "${YELLOW}Warning: NGINX_ENV is not set to 'prod'. SSL certificates are typically only needed for production.${NC}"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
fi

# Set paths (handle both relative and absolute paths)
CERT_PATH="${CERT_PATH:-./cert}"
if [[ "$CERT_PATH" = /* ]]; then
    # Absolute path
    LETSENCRYPT_DIR="${CERT_PATH}/nginx/letsencrypt"
    CERTBOT_WWW_DIR="${CERT_PATH}/nginx/certbot"
else
    # Relative path
    LETSENCRYPT_DIR="${PROJECT_ROOT}/${CERT_PATH}/nginx/letsencrypt"
    CERTBOT_WWW_DIR="${PROJECT_ROOT}/${CERT_PATH}/nginx/certbot"
fi

# Create directories if they don't exist
mkdir -p "$LETSENCRYPT_DIR"
mkdir -p "$CERTBOT_WWW_DIR"

echo -e "${GREEN}Domain: ${NGINX_HOST}${NC}"
echo -e "${GREEN}Email: ${SSL_EMAIL}${NC}"
echo -e "${GREEN}Certificate path: ${LETSENCRYPT_DIR}${NC}"
echo -e "${GREEN}Webroot path: ${CERTBOT_WWW_DIR}${NC}"

# Check if certificates already exist
if [ -f "${LETSENCRYPT_DIR}/live/${NGINX_HOST}/fullchain.pem" ]; then
    echo -e "${YELLOW}Warning: Certificates already exist for ${NGINX_HOST}${NC}"
    read -p "Do you want to renew them? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
    FORCE_RENEWAL="--force-renewal"
else
    FORCE_RENEWAL=""
fi

# Ensure nginx is running (required for ACME challenge)
echo -e "${BLUE}Checking if nginx container is running...${NC}"
cd "$PROJECT_ROOT"

if ! docker ps --format '{{.Names}}' | grep -q "^n8n_nginx$"; then
    echo -e "${YELLOW}Warning: nginx container is not running.${NC}"
    echo "Starting nginx container..."
    $DOCKER_COMPOSE up -d nginx
    echo "Waiting for nginx to be ready..."
    
    # Wait for nginx to be healthy (max 30 seconds)
    MAX_WAIT=30
    WAIT_COUNT=0
    while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
        if docker exec n8n_nginx nginx -t >/dev/null 2>&1; then
            echo -e "${GREEN}✓ Nginx is ready${NC}"
            break
        fi
        sleep 1
        WAIT_COUNT=$((WAIT_COUNT + 1))
        echo -n "."
    done
    echo
    
    if [ $WAIT_COUNT -eq $MAX_WAIT ]; then
        echo -e "${RED}Error: Nginx did not become ready in time${NC}"
        echo "Please check nginx logs: make logs-nginx"
        exit 1
    fi
else
    echo -e "${GREEN}✓ Nginx container is running${NC}"
fi

# Verify nginx can serve ACME challenge
echo -e "${BLUE}Verifying ACME challenge endpoint is accessible...${NC}"
TEST_FILE="test-$(date +%s).txt"
echo "test" > "${CERTBOT_WWW_DIR}/.well-known/acme-challenge/${TEST_FILE}"
sleep 1
if curl -s "http://${NGINX_HOST}/.well-known/acme-challenge/${TEST_FILE}" | grep -q "test"; then
    echo -e "${GREEN}✓ ACME challenge endpoint is accessible${NC}"
    rm -f "${CERTBOT_WWW_DIR}/.well-known/acme-challenge/${TEST_FILE}"
else
    echo -e "${YELLOW}⚠ Warning: Could not verify ACME challenge endpoint${NC}"
    echo "This might be okay if DNS is not pointing to this server yet"
    rm -f "${CERTBOT_WWW_DIR}/.well-known/acme-challenge/${TEST_FILE}"
fi

# Get network name from docker-compose
NETWORK_NAME=$(cd "$PROJECT_ROOT" && $DOCKER_COMPOSE ps -q nginx 2>/dev/null | xargs docker inspect --format '{{range $net, $v := .NetworkSettings.Networks}}{{$net}}{{end}}' 2>/dev/null | head -1)
if [ -z "$NETWORK_NAME" ]; then
    NETWORK_NAME="n8n_n8n_net"
fi

# Request certificate
echo -e "${BLUE}Requesting SSL certificate from Let's Encrypt...${NC}"
echo -e "${YELLOW}This may take a minute...${NC}"

if docker run --rm \
    --network "$NETWORK_NAME" \
    -v "${LETSENCRYPT_DIR}:/etc/letsencrypt" \
    -v "${CERTBOT_WWW_DIR}:/var/www/certbot" \
    certbot/certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email "${SSL_EMAIL}" \
    --agree-tos \
    --no-eff-email \
    ${FORCE_RENEWAL} \
    -d "${NGINX_HOST}"; then
    
    echo -e "${GREEN}✓ Certificate request completed${NC}"
else
    echo -e "${RED}Error: Certificate request failed${NC}"
    echo "Common issues:"
    echo "  1. Domain DNS is not pointing to this server"
    echo "  2. Port 80 is not accessible from the internet"
    echo "  3. Nginx is not serving /.well-known/acme-challenge/ correctly"
    echo ""
    echo "Check nginx logs: make logs-nginx"
    exit 1
fi

# Check if certificate was created successfully
if [ -f "${LETSENCRYPT_DIR}/live/${NGINX_HOST}/fullchain.pem" ]; then
    echo -e "${GREEN}✓ Certificate created successfully!${NC}"
    echo -e "${GREEN}Certificate location: ${LETSENCRYPT_DIR}/live/${NGINX_HOST}/${NC}"
    
    # Generate DH parameters if they don't exist
    if [ ! -f "${LETSENCRYPT_DIR}/ssl-dhparams.pem" ]; then
        echo -e "${BLUE}Generating DH parameters (this may take a few minutes)...${NC}"
        docker run --rm \
            -v "${LETSENCRYPT_DIR}:/etc/letsencrypt" \
            certbot/certbot sh -c "openssl dhparam -out /etc/letsencrypt/ssl-dhparams.pem 2048"
        echo -e "${GREEN}✓ DH parameters generated${NC}"
    else
        echo -e "${GREEN}✓ DH parameters already exist${NC}"
    fi
    
    # Download Let's Encrypt recommended SSL options if they don't exist
    if [ ! -f "${LETSENCRYPT_DIR}/options-ssl-nginx.conf" ]; then
        echo -e "${BLUE}Downloading Let's Encrypt recommended SSL options...${NC}"
        curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf \
            -o "${LETSENCRYPT_DIR}/options-ssl-nginx.conf" || {
            echo -e "${YELLOW}Warning: Could not download options-ssl-nginx.conf${NC}"
            echo "Using default SSL options (created by nginx entrypoint)"
        }
    else
        echo -e "${GREEN}✓ SSL options file already exists${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✓ SSL initialization completed!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo -e "1. Restart nginx to load HTTPS configuration:"
    echo -e "   ${YELLOW}make restart${NC}"
    echo -e "   or"
    echo -e "   ${YELLOW}$DOCKER_COMPOSE restart nginx${NC}"
    echo ""
    echo -e "2. Verify HTTPS is working:"
    echo -e "   ${YELLOW}curl -I https://${NGINX_HOST}${NC}"
    echo ""
else
    echo -e "${RED}Error: Certificate files not found after request${NC}"
    echo "Please check the certbot output above for errors"
    exit 1
fi

