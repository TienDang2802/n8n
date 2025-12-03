#!/bin/sh
# Auto-reload nginx configuration script
# This script runs in the background and periodically reloads nginx
# to pick up SSL certificate changes from Let's Encrypt renewals

set -e

# Run in background
while :; do
  sleep 6h
  if nginx -t; then
    nginx -s reload
    echo "$(date): Nginx configuration reloaded successfully"
  else
    echo "$(date): Nginx configuration test failed, skipping reload"
  fi
done &

