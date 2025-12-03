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

# Verify nginx is listening on port 80
echo -e "${BLUE}Verifying nginx is listening on port 80...${NC}"
if docker exec n8n_nginx netstat -tlnp 2>/dev/null | grep -q ":80 " || \
   docker exec n8n_nginx ss -tlnp 2>/dev/null | grep -q ":80 "; then
    echo -e "${GREEN}✓ Nginx is listening on port 80${NC}"
else
    echo -e "${RED}✗ Nginx is NOT listening on port 80${NC}"
    echo "Please check nginx logs: make logs-nginx"
    exit 1
fi

# Verify nginx can serve ACME challenge locally
echo -e "${BLUE}Verifying ACME challenge endpoint is configured...${NC}"
TEST_FILE="test-$(date +%s).txt"
mkdir -p "${CERTBOT_WWW_DIR}/.well-known/acme-challenge"
echo "test" > "${CERTBOT_WWW_DIR}/.well-known/acme-challenge/${TEST_FILE}"
chmod 644 "${CERTBOT_WWW_DIR}/.well-known/acme-challenge/${TEST_FILE}"

# Test from inside the container first
sleep 2
if docker exec n8n_nginx wget -q -O- "http://localhost/.well-known/acme-challenge/${TEST_FILE}" 2>/dev/null | grep -q "test"; then
    echo -e "${GREEN}✓ ACME challenge endpoint works inside container${NC}"
else
    echo -e "${YELLOW}⚠ Warning: ACME challenge endpoint not working inside container${NC}"
    echo "Checking nginx configuration..."
    # Test nginx config - ignore upstream resolution errors (expected if n8n isn't ready)
    NGINX_TEST_OUTPUT=$(docker exec n8n_nginx nginx -t 2>&1 || true)
    if echo "$NGINX_TEST_OUTPUT" | grep -q "configuration file.*test is successful"; then
        echo -e "${GREEN}✓ Nginx configuration syntax is valid${NC}"
    elif echo "$NGINX_TEST_OUTPUT" | grep -q "host not found in upstream"; then
        echo -e "${YELLOW}⚠ Nginx config shows upstream resolution warning (this is normal)${NC}"
        echo -e "${YELLOW}  Nginx will resolve 'n8n' dynamically when handling requests${NC}"
        echo -e "${GREEN}✓ Configuration syntax is OK, proceeding...${NC}"
    else
        echo -e "${RED}✗ Nginx configuration has errors:${NC}"
        echo "$NGINX_TEST_OUTPUT"
        echo ""
        echo "Please check nginx logs: make logs-nginx"
        exit 1
    fi
    docker exec n8n_nginx cat /etc/nginx/conf.d/n8n.conf | grep -A 5 "acme-challenge" || echo "ACME challenge location not found in config"
fi

# Test from host (if DNS is configured)
echo -e "${BLUE}Testing external accessibility...${NC}"
if curl -s --max-time 5 "http://${NGINX_HOST}/.well-known/acme-challenge/${TEST_FILE}" 2>/dev/null | grep -q "test"; then
    echo -e "${GREEN}✓ ACME challenge endpoint is accessible from internet${NC}"
    EXTERNAL_ACCESS=true
else
    echo -e "${YELLOW}⚠ Warning: Could not verify external accessibility${NC}"
    echo "This could mean:"
    echo "  1. DNS is not pointing to this server yet"
    echo "  2. Port 80 is blocked by firewall"
    echo "  3. Server IP doesn't match DNS A record"
    echo ""
    echo "Checking server IP..."
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || echo "unknown")
    echo "  Server IP: ${SERVER_IP}"
    echo "  Domain: ${NGINX_HOST}"
    echo ""
    echo "Please verify:"
    echo "  1. DNS A record for ${NGINX_HOST} points to ${SERVER_IP}"
    echo "  2. Port 80 is open in firewall: sudo ufw allow 80/tcp"
    echo "  3. Port 80 is not blocked by cloud provider security groups"
    EXTERNAL_ACCESS=false
fi

rm -f "${CERTBOT_WWW_DIR}/.well-known/acme-challenge/${TEST_FILE}"

if [ "$EXTERNAL_ACCESS" = "false" ]; then
    echo ""
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted. Please fix the issues above and try again."
        exit 1
    fi
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
    echo ""
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}Troubleshooting Steps:${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo ""
    echo "1. Check if nginx is running:"
    echo "   ${BLUE}docker ps | grep nginx${NC}"
    echo ""
    echo "2. Check if nginx is listening on port 80:"
    echo "   ${BLUE}docker exec n8n_nginx netstat -tlnp | grep 80${NC}"
    echo "   or"
    echo "   ${BLUE}sudo netstat -tlnp | grep 80${NC}"
    echo ""
    echo "3. Check firewall (if using ufw):"
    echo "   ${BLUE}sudo ufw status${NC}"
    echo "   ${BLUE}sudo ufw allow 80/tcp${NC}"
    echo ""
    echo "4. Check if port 80 is accessible from internet:"
    echo "   ${BLUE}curl -I http://${NGINX_HOST}/.well-known/acme-challenge/test${NC}"
    echo ""
    echo "5. Verify DNS points to this server:"
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || echo "unknown")
    echo "   ${BLUE}dig ${NGINX_HOST}${NC}"
    echo "   Server IP should be: ${SERVER_IP}"
    echo ""
    echo "6. Check nginx configuration:"
    echo "   ${BLUE}docker exec n8n_nginx nginx -t${NC}"
    echo "   ${BLUE}docker exec n8n_nginx cat /etc/nginx/conf.d/n8n.conf${NC}"
    echo ""
    echo "7. Check nginx logs:"
    echo "   ${BLUE}make logs-nginx${NC}"
    echo ""
    echo "8. Test ACME challenge endpoint manually:"
    echo "   ${BLUE}echo 'test' > cert/nginx/certbot/.well-known/acme-challenge/test${NC}"
    echo "   ${BLUE}curl http://${NGINX_HOST}/.well-known/acme-challenge/test${NC}"
    echo ""
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

