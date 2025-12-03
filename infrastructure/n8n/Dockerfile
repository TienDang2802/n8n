# n8n Dockerfile
# Base image: Official n8n image
ARG N8N_VERSION=latest
FROM n8nio/n8n:${N8N_VERSION}

# Set timezone
ENV TZ=Asia/Ho_Chi_Minh

# Switch to root to install additional packages if needed
USER root

# Install additional system packages if needed
# Uncomment and add packages as required
# Example: Install curl, git, or other tools
# RUN apk add --no-cache \
#     curl \
#     git \
#     && rm -rf /var/cache/apk/*

# Install additional npm packages globally if needed
# These packages can be used in n8n Function nodes
# Example: Install specific npm packages
# RUN npm install -g \
#     package-name-1 \
#     package-name-2

# Set environment variable to allow external npm modules in Function nodes
# Use specific package names for security, or '*' to allow all (not recommended)
# ENV NODE_FUNCTION_ALLOW_EXTERNAL=package-name-1,package-name-2

# Install su-exec for user switching (Alpine) or use gosu (Debian-based)
RUN (apk add --no-cache su-exec 2>/dev/null) || \
    (apt-get update && apt-get install -y gosu && rm -rf /var/lib/apt/lists/* 2>/dev/null) || \
    echo "Note: su-exec/gosu not available, permissions will be fixed by entrypoint"

# Create necessary directories and set permissions
RUN mkdir -p /home/node/.n8n && \
    chown -R node:node /home/node/.n8n

# Copy entrypoint script to fix permissions on mounted volumes
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint-wrapper.sh
RUN chmod +x /usr/local/bin/docker-entrypoint-wrapper.sh

# Keep as root - entrypoint will switch to node user after fixing permissions
# USER node

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=60s \
    CMD wget --no-verbose --tries=1 --spider http://localhost:5678/ || exit 1

# Expose n8n port (internal use, not exposed to host in production)
EXPOSE 5678

# Use wrapper entrypoint that fixes permissions before starting n8n
ENTRYPOINT ["/usr/local/bin/docker-entrypoint-wrapper.sh"]

