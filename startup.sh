#!/bin/bash

# Startup script for Blue/Green deployment
set -e

echo "Starting Blue/Green deployment with ACTIVE_POOL=${ACTIVE_POOL}"

# Copy our template with custom logging to nginx.conf
cp /etc/nginx/templates/nginx.conf.template /etc/nginx/nginx.conf

# Create log directory if it doesn't exist
mkdir -p /var/log/nginx
touch /var/log/nginx/custom_access.log
touch /var/log/nginx/error.log
chmod 644 /var/log/nginx/custom_access.log /var/log/nginx/error.log

echo "Nginx configuration generated successfully"
echo "Starting Nginx..."

# Start Nginx
exec nginx -g 'daemon off;'