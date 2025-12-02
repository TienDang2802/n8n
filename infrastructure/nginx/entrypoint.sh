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

# Clear existing configs
rm -f "${OUTPUT_DIR}"/*.conf

# Check if SSL certificates exist (for prod mode only)
CERT_PATH="/etc/letsencrypt/live/${NGINX_HOST}/fullchain.pem"
HAS_CERT=false

if [ "${NGINX_ENV}" = "prod" ]; then
  if [ -f "${CERT_PATH}" ]; then
    HAS_CERT=true
    echo "SSL certificates found at ${CERT_PATH}"
  else
    echo "SSL certificates not found. Using initial HTTP configuration for ACME challenge."
  fi
fi

# Render templates based on environment and certificate status
if [ "${NGINX_ENV}" = "dev" ]; then
  # Dev mode: render all templates
  for tmpl in "${TEMPLATE_DIR}"/*.conf.template; do
    [ -e "$tmpl" ] || continue
    name=$(basename "$tmpl" .template)
    echo "Rendering $tmpl -> ${OUTPUT_DIR}/${name}"
    envsubst '${NGINX_HOST} ${NGINX_PORT}' < "$tmpl" > "${OUTPUT_DIR}/${name}"
  done
elif [ "${NGINX_ENV}" = "prod" ]; then
  if [ "$HAS_CERT" = "false" ]; then
    # No certificates: use initial HTTP template only
    INIT_TEMPLATE="${TEMPLATE_DIR}/n8n-http-init.conf.template"
    if [ -f "${INIT_TEMPLATE}" ]; then
      echo "Rendering ${INIT_TEMPLATE} -> ${OUTPUT_DIR}/n8n-http-init.conf"
      envsubst '${NGINX_HOST} ${NGINX_PORT}' < "${INIT_TEMPLATE}" > "${OUTPUT_DIR}/n8n-http-init.conf"
    else
      echo "ERROR: Initial template ${INIT_TEMPLATE} not found!"
      exit 1
    fi
  else
    # Certificates exist: use production HTTP + HTTPS templates
    # Use the combined template if available, otherwise use separate templates
    COMBINED_TEMPLATE="${TEMPLATE_DIR}/n8n.conf.template"
    HTTP_PROD_TEMPLATE="${TEMPLATE_DIR}/n8n-http-prod.conf.template"
    HTTPS_TEMPLATE="${TEMPLATE_DIR}/n8n-https.conf.template"
    
    if [ -f "${COMBINED_TEMPLATE}" ]; then
      # Use combined template (simpler)
      echo "Rendering ${COMBINED_TEMPLATE} -> ${OUTPUT_DIR}/n8n.conf"
      envsubst '${NGINX_HOST} ${NGINX_PORT}' < "${COMBINED_TEMPLATE}" > "${OUTPUT_DIR}/n8n.conf"
    elif [ -f "${HTTP_PROD_TEMPLATE}" ] && [ -f "${HTTPS_TEMPLATE}" ]; then
      # Use separate templates
      echo "Rendering ${HTTP_PROD_TEMPLATE} -> ${OUTPUT_DIR}/n8n-http-prod.conf"
      envsubst '${NGINX_HOST} ${NGINX_PORT}' < "${HTTP_PROD_TEMPLATE}" > "${OUTPUT_DIR}/n8n-http-prod.conf"
      echo "Rendering ${HTTPS_TEMPLATE} -> ${OUTPUT_DIR}/n8n-https.conf"
      envsubst '${NGINX_HOST} ${NGINX_PORT}' < "${HTTPS_TEMPLATE}" > "${OUTPUT_DIR}/n8n-https.conf"
    else
      echo "ERROR: No suitable production template found!"
      exit 1
    fi
  fi
fi

echo "Configuration files generated:"
ls -la "${OUTPUT_DIR}"/*.conf 2>/dev/null || echo "  (no config files)"

echo "Starting nginx..."
exec nginx -g 'daemon off;'
