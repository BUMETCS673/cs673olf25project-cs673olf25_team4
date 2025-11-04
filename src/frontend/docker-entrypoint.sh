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
  # Ensure we don't leave an HTTPS config behind (from previous builds/containers)
  if [ -f /etc/nginx/conf.d/https.conf ]; then
    echo "Removing leftover HTTPS config (/etc/nginx/conf.d/https.conf) to run HTTP only"
    rm -f /etc/nginx/conf.d/https.conf || true
  fi
fi

# Defensive: if certs are mounted directly into /etc/nginx/ssl (e.g. via docker-compose)
# and have expected names (fullchain.pem/privkey.pem), treat them as found.
if [ -f "/etc/nginx/ssl/fullchain.pem" ] && [ -f "/etc/nginx/ssl/privkey.pem" ]; then
  echo "Found certs in /etc/nginx/ssl; enabling HTTPS configs where applicable";
  # Make sure https.conf is created from template if not already
  if [ ! -f /etc/nginx/conf.d/https.conf ] && [ -f /etc/nginx/conf.d/https.conf.template ]; then
    # Ensure template references the correct backend service name for dev
    sed -i 's|concert_backend_prod|backend|g' /etc/nginx/conf.d/https.conf.template || true
    cp /etc/nginx/conf.d/https.conf.template /etc/nginx/conf.d/https.conf || true
  fi
fi

# Fallback: if server.crt/server.key exist but fullchain/privkey do not, copy them to expected filenames
if [ -f "/etc/nginx/ssl/server.crt" ] && [ -f "/etc/nginx/ssl/server.key" ]; then
  echo "Detected /etc/nginx/ssl/server.crt and server.key; updating template to use these files"
  # Update template to use server.crt/server.key directly (don't copy files into read-only mounts)
  if [ -f /etc/nginx/conf.d/https.conf.template ]; then
    sed -i 's|ssl_certificate .*|ssl_certificate /etc/nginx/ssl/server.crt;|g' /etc/nginx/conf.d/https.conf.template || true
    sed -i 's|ssl_certificate_key .*|ssl_certificate_key /etc/nginx/ssl/server.key;|g' /etc/nginx/conf.d/https.conf.template || true
    sed -i 's|ssl_trusted_certificate .*|ssl_trusted_certificate /etc/nginx/ssl/server.crt;|g' /etc/nginx/conf.d/https.conf.template || true
    # Also ensure backend host in template is set to the dev service name
    sed -i 's|concert_backend_prod|backend|g' /etc/nginx/conf.d/https.conf.template || true
    # Activate the https config from the updated template
    cp /etc/nginx/conf.d/https.conf.template /etc/nginx/conf.d/https.conf || true
  fi
fi

# Test nginx configuration
echo "Testing NGINX configuration..."
nginx -t

# Start nginx
echo "Starting NGINX..."
exec nginx -g "daemon off;"