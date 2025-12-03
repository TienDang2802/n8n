FROM nginx:alpine

# Install required packages
# - bash: for entrypoint script
# - gettext: for envsubst (template variable substitution)
# - openssl: for generating dhparams
# - curl: for downloading SSL options in init script
RUN apk add --no-cache bash gettext openssl curl

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Copy templates
COPY templates/ /etc/nginx/templates/

# Copy entrypoint script and make it executable
COPY entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

EXPOSE 80 443

# Use our custom entrypoint
ENTRYPOINT ["/docker-entrypoint.sh"]
