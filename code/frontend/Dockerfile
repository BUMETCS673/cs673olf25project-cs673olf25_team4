FROM nginx:alpine

# Remove default nginx config and use a simple one that serves /usr/share/nginx/html
RUN rm /etc/nginx/conf.d/default.conf

COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy static site files
COPY public /usr/share/nginx/html

# Expose a non-standard host port (mapped by docker-compose)
EXPOSE 80
