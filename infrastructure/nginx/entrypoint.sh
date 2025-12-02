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

# Render tất cả *.conf.template trong thư mục env tương ứng
for tmpl in "${TEMPLATE_DIR}"/*.conf.template; do
  [ -e "$tmpl" ] || continue
  name=$(basename "$tmpl" .template)
  echo "Rendering $tmpl -> ${OUTPUT_DIR}/${name}"
  envsubst '${NGINX_HOST} ${NGINX_PORT}' < "$tmpl" > "${OUTPUT_DIR}/${name}"
done

echo "Starting nginx..."
exec nginx -g 'daemon off;'
