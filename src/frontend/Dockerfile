# ---- Build Stage ----
FROM node:20-alpine AS build

# Set working directory
WORKDIR /app

# Copy package.json and lock file first (for caching)
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy the rest of the project
COPY . .

# Build the Vite app
RUN npm run build


# ---- Production Stage ----
FROM nginx:alpine

# Install openssl for SSL certificate handling
RUN apk add --no-cache openssl

# Copy custom nginx configurations
# nginx.conf is for HTTP, nginx-ssl.conf is for HTTPS
COPY nginx.conf /etc/nginx/conf.d/http.conf
COPY nginx-ssl.conf /etc/nginx/conf.d/https.conf.template

# Copy built assets from build stage
COPY --from=build /app/dist /usr/share/nginx/html

# Create SSL certificate directory
RUN mkdir -p /etc/nginx/ssl

# Create startup script to configure SSL
RUN echo '#!/bin/sh' > /docker-entrypoint.sh && \
    echo 'set -e' >> /docker-entrypoint.sh && \
    echo '' >> /docker-entrypoint.sh && \
    echo '# Check if SSL certificates are mounted and configure accordingly' >> /docker-entrypoint.sh && \
    echo 'if [ -f "/etc/nginx/ssl/fullchain.pem" ] || [ -f "/etc/nginx/ssl/cert.pem" ]; then' >> /docker-entrypoint.sh && \
    echo '  echo "SSL certificates found, activating HTTPS configuration..."' >> /docker-entrypoint.sh && \
    echo '  ' >> /docker-entrypoint.sh && \
    echo '  # Determine cert file name' >> /docker-entrypoint.sh && \
    echo '  if [ -f "/etc/nginx/ssl/fullchain.pem" ]; then' >> /docker-entrypoint.sh && \
    echo '    CERT_FILE="/etc/nginx/ssl/fullchain.pem"' >> /docker-entrypoint.sh && \
    echo '  else' >> /docker-entrypoint.sh && \
    echo '    CERT_FILE="/etc/nginx/ssl/cert.pem"' >> /docker-entrypoint.sh && \
    echo '  fi' >> /docker-entrypoint.sh && \
    echo '  ' >> /docker-entrypoint.sh && \
    echo '  # Update SSL configuration with correct paths' >> /docker-entrypoint.sh && \
    echo '  sed -i "s|ssl_certificate /etc/nginx/ssl/dev/server.crt;|ssl_certificate $CERT_FILE;|g" /etc/nginx/conf.d/https.conf.template' >> /docker-entrypoint.sh && \
    echo '  sed -i "s|ssl_certificate_key /etc/nginx/ssl/dev/server.key;|ssl_certificate_key /etc/nginx/ssl/privkey.pem;|g" /etc/nginx/conf.d/https.conf.template' >> /docker-entrypoint.sh && \
    echo '  sed -i "s|ssl_trusted_certificate /etc/nginx/ssl/dev/server.crt;|ssl_trusted_certificate $CERT_FILE;|g" /etc/nginx/conf.d/https.conf.template' >> /docker-entrypoint.sh && \
    echo '  ' >> /docker-entrypoint.sh && \
    echo '  # Generate dhparam if it does not exist (optional, can be slow)' >> /docker-entrypoint.sh && \
    echo '  if [ ! -f "/etc/nginx/ssl/dhparam.pem" ]; then' >> /docker-entrypoint.sh && \
    echo '    echo "Generating dhparam (this may take a minute)..."' >> /docker-entrypoint.sh && \
    echo '    openssl dhparam -out /etc/nginx/ssl/dhparam.pem 2048 2>/dev/null || echo "# dhparam generation skipped" > /etc/nginx/ssl/dhparam.pem' >> /docker-entrypoint.sh && \
    echo '  fi' >> /docker-entrypoint.sh && \
    echo '  ' >> /docker-entrypoint.sh && \
    echo '  # Comment out dhparam line if file is just a comment' >> /docker-entrypoint.sh && \
    echo '  if grep -q "^#" /etc/nginx/ssl/dhparam.pem; then' >> /docker-entrypoint.sh && \
    echo '    sed -i "s|ssl_dhparam /etc/nginx/ssl/dhparam.pem;|# ssl_dhparam disabled|g" /etc/nginx/conf.d/https.conf.template' >> /docker-entrypoint.sh && \
    echo '  fi' >> /docker-entrypoint.sh && \
    echo '  ' >> /docker-entrypoint.sh && \
    echo '  # Activate SSL configuration' >> /docker-entrypoint.sh && \
    echo '  cp /etc/nginx/conf.d/https.conf.template /etc/nginx/conf.d/https.conf' >> /docker-entrypoint.sh && \
    echo '  echo "HTTPS configuration activated"' >> /docker-entrypoint.sh && \
    echo 'else' >> /docker-entrypoint.sh && \
    echo '  echo "No SSL certificates found, running HTTP only"' >> /docker-entrypoint.sh && \
    echo 'fi' >> /docker-entrypoint.sh && \
    echo '' >> /docker-entrypoint.sh && \
    echo '# Test nginx configuration' >> /docker-entrypoint.sh && \
    echo 'nginx -t' >> /docker-entrypoint.sh && \
    echo '' >> /docker-entrypoint.sh && \
    echo '# Start nginx' >> /docker-entrypoint.sh && \
    echo 'exec nginx -g "daemon off;"' >> /docker-entrypoint.sh && \
    chmod +x /docker-entrypoint.sh

# Expose ports 80 (HTTP) and 443 (HTTPS)
EXPOSE 80 443

# Use custom entrypoint
ENTRYPOINT ["/docker-entrypoint.sh"]