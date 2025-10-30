#!/bin/bash

# Startup script for Blue/Green deployment
set -e

echo "Starting Blue/Green deployment with ACTIVE_POOL=${ACTIVE_POOL}"

# Create nginx configuration based on ACTIVE_POOL
cat > /etc/nginx/nginx.conf << EOF
events {
    worker_connections 1024;
}

http {
    # Upstream definitions with failover configuration
    upstream active_upstream {
        # Primary and backup configuration based on ACTIVE_POOL
        server app-blue:3000 max_fails=1 fail_timeout=5s;
        server app-green:3000 backup;
    }

    # Logging
    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for" '
                    'upstream: \$upstream_addr status: \$upstream_status';

    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log warn;

    # Main server block - port 80
    server {
        listen 80;
        server_name localhost;

        # Health check endpoint
        location /healthz {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }

        # Main application proxy
        location / {
            # Use active upstream
            proxy_pass http://active_upstream;
            
            # Proxy headers
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            
            # Timeout settings for quick failure detection
            proxy_connect_timeout 2s;
            proxy_send_timeout 2s;
            proxy_read_timeout 2s;
            
            # Retry configuration
            proxy_next_upstream error timeout http_500 http_502 http_503 http_504;
            proxy_next_upstream_tries 2;
            proxy_next_upstream_timeout 2s;
            
            # Preserve all upstream headers
            proxy_pass_header X-App-Pool;
            proxy_pass_header X-Release-Id;
            proxy_pass_header Server;
            proxy_pass_header Date;
            proxy_pass_header Content-Type;
            proxy_pass_header Content-Length;
            proxy_pass_header Cache-Control;
            proxy_pass_header Expires;
            proxy_pass_header Last-Modified;
            proxy_pass_header ETag;
            
            # Buffer settings
            proxy_buffering on;
            proxy_buffer_size 4k;
            proxy_buffers 8 4k;
        }
    }

    # Additional server block for port 8080
    server {
        listen 8080;
        server_name localhost;

        # Health check endpoint
        location /healthz {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }

        # Main application proxy
        location / {
            # Use active upstream
            proxy_pass http://active_upstream;
            
            # Proxy headers
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            
            # Timeout settings for quick failure detection
            proxy_connect_timeout 2s;
            proxy_send_timeout 2s;
            proxy_read_timeout 2s;
            
            # Retry configuration
            proxy_next_upstream error timeout http_500 http_502 http_503 http_504;
            proxy_next_upstream_tries 2;
            proxy_next_upstream_timeout 10s;
            
            # Preserve all upstream headers
            proxy_pass_header X-App-Pool;
            proxy_pass_header X-Release-Id;
            proxy_pass_header Server;
            proxy_pass_header Date;
            proxy_pass_header Content-Type;
            proxy_pass_header Content-Length;
            proxy_pass_header Cache-Control;
            proxy_pass_header Expires;
            proxy_pass_header Last-Modified;
            proxy_pass_header ETag;
            
            # Buffer settings
            proxy_buffering on;
            proxy_buffer_size 4k;
            proxy_buffers 8 4k;
        }
    }

}
EOF

echo "Nginx configuration generated successfully"
echo "Starting Nginx..."

# Start Nginx
exec nginx -g 'daemon off;'