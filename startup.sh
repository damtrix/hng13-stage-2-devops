#!/bin/bash

# Startup script for Blue/Green deployment
set -e

echo "Starting Blue/Green deployment with ACTIVE_POOL=${ACTIVE_POOL}"

# Render template: replace ${ACTIVE_POOL} placeholders with the environment value
# Use sed to perform a simple variable substitution so nginx receives a static config
sed "s/\${ACTIVE_POOL}/${ACTIVE_POOL}/g" /etc/nginx/templates/nginx.conf.template > /etc/nginx/nginx.conf

# Create log directory if it doesn't exist
mkdir -p /var/log/nginx
touch /var/log/nginx/custom_access.log
touch /var/log/nginx/error.log
chmod 644 /var/log/nginx/custom_access.log /var/log/nginx/error.log

echo "Nginx configuration generated successfully"
echo "Starting Nginx..."

# Start Nginx
exec nginx -g 'daemon off;'