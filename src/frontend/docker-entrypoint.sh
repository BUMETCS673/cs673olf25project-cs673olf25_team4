#!/bin/sh
set -e

echo "Starting NGINX SSL configuration..."

# Find and copy SSL certificates from letsencrypt to nginx ssl directory
CERT_FOUND=false
if [ -d "/etc/letsencrypt/live" ]; then
  for domain_dir in /etc/letsencrypt/live/*; do
    if [ -d "$domain_dir" ] && [ -f "$domain_dir/fullchain.pem" ]; then
      echo "Found SSL certificates in $domain_dir"
      # Copy actual certificate files (resolve symlinks with -L flag)
      cp -L "$domain_dir/fullchain.pem" /etc/nginx/ssl/fullchain.pem 2>/dev/null || true
      cp -L "$domain_dir/privkey.pem" /etc/nginx/ssl/privkey.pem 2>/dev/null || true
      cp -L "$domain_dir/chain.pem" /etc/nginx/ssl/chain.pem 2>/dev/null || true
      if [ -f "/etc/nginx/ssl/fullchain.pem" ] && [ -f "/etc/nginx/ssl/privkey.pem" ]; then
        CERT_FOUND=true
        echo "SSL certificates copied successfully"
        break
      fi
    fi
  done
fi

# Configure NGINX based on certificate availability
if [ "$CERT_FOUND" = "true" ]; then
  echo "Activating HTTPS configuration..."

  # Update SSL configuration with correct paths
  sed -i "s|ssl_certificate /etc/nginx/ssl/dev/server.crt;|ssl_certificate /etc/nginx/ssl/fullchain.pem;|g" /etc/nginx/conf.d/https.conf.template
  sed -i "s|ssl_certificate_key /etc/nginx/ssl/dev/server.key;|ssl_certificate_key /etc/nginx/ssl/privkey.pem;|g" /etc/nginx/conf.d/https.conf.template
  sed -i "s|ssl_trusted_certificate /etc/nginx/ssl/dev/server.crt;|ssl_trusted_certificate /etc/nginx/ssl/fullchain.pem;|g" /etc/nginx/conf.d/https.conf.template

  # Disable dhparam (optional security feature that's very slow to generate)
  sed -i "s|ssl_dhparam /etc/nginx/ssl/dhparam.pem;|# ssl_dhparam disabled for faster startup|g" /etc/nginx/conf.d/https.conf.template

  # Disable HTTP-only config to prevent port 80 conflict
  rm -f /etc/nginx/conf.d/http.conf

  # Activate SSL configuration
  cp /etc/nginx/conf.d/https.conf.template /etc/nginx/conf.d/https.conf
  echo "HTTPS configuration activated"
else
  echo "No SSL certificates found, running HTTP only"
fi

# Test nginx configuration
echo "Testing NGINX configuration..."
nginx -t

# Start nginx
echo "Starting NGINX..."
exec nginx -g "daemon off;"