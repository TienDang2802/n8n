#!/bin/bash
# Initialize Let's Encrypt SSL certificates
# This script should be run once to generate the initial SSL certificates
# Based on: https://dev.to/marrouchi/the-challenge-about-ssl-in-docker-containers-no-one-talks-about-32gh

set -e

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="${PROJECT_ROOT}/.env"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Initializing Let's Encrypt SSL certificates...${NC}"

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

# Set paths
CERT_PATH="${CERT_PATH:-./cert}"
LETSENCRYPT_DIR="${PROJECT_ROOT}/${CERT_PATH}/nginx/letsencrypt"
CERTBOT_WWW_DIR="${PROJECT_ROOT}/${CERT_PATH}/nginx/certbot"

# Create directories if they don't exist
mkdir -p "$LETSENCRYPT_DIR"
mkdir -p "$CERTBOT_WWW_DIR"

echo -e "${GREEN}Domain: ${NGINX_HOST}${NC}"
echo -e "${GREEN}Email: ${SSL_EMAIL}${NC}"
echo -e "${GREEN}Certificate path: ${LETSENCRYPT_DIR}${NC}"

# Check if certificates already exist
if [ -d "${LETSENCRYPT_DIR}/live/${NGINX_HOST}" ]; then
    echo -e "${YELLOW}Warning: Certificates already exist for ${NGINX_HOST}${NC}"
    read -p "Do you want to renew them? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
fi

# Ensure nginx is running (required for ACME challenge)
echo -e "${GREEN}Checking if nginx container is running...${NC}"
if ! docker ps | grep -q n8n_nginx; then
    echo -e "${YELLOW}Warning: nginx container is not running.${NC}"
    echo "Starting nginx container..."
    cd "$PROJECT_ROOT"
    docker compose up -d nginx
    echo "Waiting for nginx to be ready..."
    sleep 5
fi

# Request certificate
echo -e "${GREEN}Requesting SSL certificate from Let's Encrypt...${NC}"
docker run --rm \
    -v "${LETSENCRYPT_DIR}:/etc/letsencrypt" \
    -v "${CERTBOT_WWW_DIR}:/var/www/certbot" \
    certbot/certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email "${SSL_EMAIL}" \
    --agree-tos \
    --no-eff-email \
    --force-renewal \
    -d "${NGINX_HOST}"

# Check if certificate was created successfully
if [ -f "${LETSENCRYPT_DIR}/live/${NGINX_HOST}/fullchain.pem" ]; then
    echo -e "${GREEN}✓ Certificate created successfully!${NC}"
    echo -e "${GREEN}Certificate location: ${LETSENCRYPT_DIR}/live/${NGINX_HOST}/${NC}"
    
    # Generate DH parameters if they don't exist
    if [ ! -f "${LETSENCRYPT_DIR}/ssl-dhparams.pem" ]; then
        echo -e "${GREEN}Generating DH parameters (this may take a few minutes)...${NC}"
        docker run --rm \
            -v "${LETSENCRYPT_DIR}:/etc/letsencrypt" \
            certbot/certbot sh -c "openssl dhparam -out /etc/letsencrypt/ssl-dhparams.pem 2048"
        echo -e "${GREEN}✓ DH parameters generated${NC}"
    fi
    
    # Download Let's Encrypt recommended SSL options if they don't exist
    if [ ! -f "${LETSENCRYPT_DIR}/options-ssl-nginx.conf" ]; then
        echo -e "${GREEN}Downloading Let's Encrypt recommended SSL options...${NC}"
        curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf \
            -o "${LETSENCRYPT_DIR}/options-ssl-nginx.conf"
        echo -e "${GREEN}✓ SSL options downloaded${NC}"
    fi
    
    echo -e "${GREEN}✓ SSL initialization completed!${NC}"
    echo -e "${YELLOW}Note: Make sure nginx is configured to use these certificates.${NC}"
    echo -e "${YELLOW}Restart nginx if needed: docker compose restart nginx${NC}"
else
    echo -e "${RED}Error: Certificate creation failed${NC}"
    exit 1
fi

