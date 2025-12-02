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

# Create necessary directories and set permissions
RUN mkdir -p /home/node/.n8n && \
    chown -R node:node /home/node/.n8n

# Switch back to node user for security
USER node

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=60s \
    CMD wget --no-verbose --tries=1 --spider http://localhost:5678/ || exit 1

# Expose n8n port (internal use, not exposed to host in production)
EXPOSE 5678

# n8n entrypoint is already set in base image
# No need to override CMD unless custom startup is required

