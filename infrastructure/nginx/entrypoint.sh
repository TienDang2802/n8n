#!/bin/sh
set -e

# Biến mặc định nếu chưa set trong docker-compose
: "${NGINX_HOST:=localhost}"
: "${NGINX_PORT:=443}"
: "${NGINX_ENV:=prod}"    # prod | dev

TEMPLATE_DIR="/etc/nginx/templates/${NGINX_ENV}"
OUTPUT_DIR="/etc/nginx/conf.d"

echo "Using NGINX_ENV=${NGINX_ENV}"
echo "Rendering templates from ${TEMPLATE_DIR} to ${OUTPUT_DIR}"

mkdir -p "${OUTPUT_DIR}"

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

# Render tất cả *.conf.template trong thư mục env tương ứng
for tmpl in "${TEMPLATE_DIR}"/*.conf.template; do
  [ -e "$tmpl" ] || continue
  name=$(basename "$tmpl" .template)
  echo "Rendering $tmpl -> ${OUTPUT_DIR}/${name}"
  envsubst '${NGINX_HOST} ${NGINX_PORT}' < "$tmpl" > "${OUTPUT_DIR}/${name}"
done

echo "Starting nginx..."
exec nginx -g 'daemon off;'
