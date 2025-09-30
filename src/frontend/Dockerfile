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

# Expose ports 80 (HTTP) and 443 (HTTPS)
EXPOSE 80 443

# Start nginx
# Note: SSL configuration will be activated when certificates are mounted
CMD ["nginx", "-g", "daemon off;"]