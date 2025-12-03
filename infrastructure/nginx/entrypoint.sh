#!/bin/sh
set -e

# Biến mặc định nếu chưa set trong docker-compose
: "${NGINX_HOST:=localhost}"
: "${NGINX_PORT:=443}"
: "${NGINX_ENV:=prod}"    # prod | dev

TEMPLATE_DIR="/etc/nginx/templates/${NGINX_ENV}"
OUTPUT_DIR="/etc/nginx/conf.d"

echo "=========================================="
echo "Nginx Entrypoint Script"
echo "=========================================="
echo "NGINX_ENV=${NGINX_ENV}"
echo "NGINX_HOST=${NGINX_HOST}"
echo "NGINX_PORT=${NGINX_PORT}"
echo "=========================================="

mkdir -p "${OUTPUT_DIR}"

# For PROD environment, check if SSL certificates exist
if [ "${NGINX_ENV}" = "prod" ]; then
  CERT_DIR="/etc/letsencrypt/live/${NGINX_HOST}"
  FULLCHAIN="${CERT_DIR}/fullchain.pem"
  PRIVKEY="${CERT_DIR}/privkey.pem"
  
  if [ -f "${FULLCHAIN}" ] && [ -f "${PRIVKEY}" ]; then
    echo "✓ SSL certificates found: ${CERT_DIR}"
    echo "Using HTTPS configuration"
    USE_HTTPS=true
  else
    echo "⚠ SSL certificates not found: ${CERT_DIR}"
    echo "Using HTTP-only configuration (for initial setup and ACME challenge)"
    USE_HTTPS=false
  fi
  
  # Create Let's Encrypt SSL configuration files if they don't exist
  # These are typically created by certbot, but we provide defaults for initial setup
  if [ ! -f /etc/letsencrypt/options-ssl-nginx.conf ]; then
    echo "Creating default options-ssl-nginx.conf..."
    mkdir -p /etc/letsencrypt
    cat > /etc/letsencrypt/options-ssl-nginx.conf << 'EOF'
# This file is created automatically. It will be replaced by certbot.
ssl_session_cache shared:le_nginx_SSL:10m;
ssl_session_timeout 1440m;
ssl_session_tickets off;
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers off;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
EOF
  fi

  if [ ! -f /etc/letsencrypt/ssl-dhparams.pem ]; then
    echo "Generating ssl-dhparams.pem (this may take a few minutes)..."
    mkdir -p /etc/letsencrypt
    # Generate DH parameters (2048 bits is sufficient and faster)
    openssl dhparam -out /etc/letsencrypt/ssl-dhparams.pem 2048 2>/dev/null || {
      echo "Warning: Could not generate dhparams. Using fallback."
      # Create a minimal file to prevent nginx errors
      touch /etc/letsencrypt/ssl-dhparams.pem
    }
  fi
  
  # Select appropriate template based on certificate existence
  if [ "$USE_HTTPS" = "true" ]; then
    TEMPLATE_FILE="${TEMPLATE_DIR}/n8n-https.conf.template"
    OUTPUT_FILE="${OUTPUT_DIR}/n8n.conf"
  else
    TEMPLATE_FILE="${TEMPLATE_DIR}/n8n-http-only.conf.template"
    OUTPUT_FILE="${OUTPUT_DIR}/n8n.conf"
  fi
  
  if [ -f "${TEMPLATE_FILE}" ]; then
    echo "Rendering ${TEMPLATE_FILE} -> ${OUTPUT_FILE}"
    envsubst '${NGINX_HOST} ${NGINX_PORT}' < "${TEMPLATE_FILE}" > "${OUTPUT_FILE}"
  else
    echo "ERROR: Template file not found: ${TEMPLATE_FILE}"
    exit 1
  fi
else
  # DEV environment - use all templates in dev directory
  echo "Rendering templates from ${TEMPLATE_DIR} to ${OUTPUT_DIR}"
  for tmpl in "${TEMPLATE_DIR}"/*.conf.template; do
    [ -e "$tmpl" ] || continue
    name=$(basename "$tmpl" .template)
    echo "Rendering $tmpl -> ${OUTPUT_DIR}/${name}"
    envsubst '${NGINX_HOST} ${NGINX_PORT}' < "$tmpl" > "${OUTPUT_DIR}/${name}"
  done
fi

# Test nginx configuration
echo "Testing nginx configuration..."
if nginx -t; then
  echo "✓ Nginx configuration is valid"
else
  echo "✗ Nginx configuration test failed"
  exit 1
fi

echo "Starting nginx..."
exec nginx -g 'daemon off;'
