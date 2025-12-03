#!/bin/sh
set -e

# Fix permissions for n8n data directory
# This ensures the node user (UID 1000) can write to the mounted volume
if [ "$(id -u)" = "0" ]; then
    if [ -d /home/node/.n8n ]; then
        echo "Fixing permissions for /home/node/.n8n..."
        chown -R node:node /home/node/.n8n
        chmod -R 755 /home/node/.n8n
    fi
    
    # Switch to node user and execute n8n
    # Try su-exec first (Alpine), then gosu (Debian), then su as fallback
    if command -v su-exec >/dev/null 2>&1; then
        exec su-exec node n8n "$@"
    elif command -v gosu >/dev/null 2>&1; then
        exec gosu node n8n "$@"
    else
        exec su -s /bin/sh node -c "exec n8n $*"
    fi
fi

# If we're already the node user, execute n8n directly
exec n8n "$@"

