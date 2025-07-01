#!/bin/bash

# A script to set up or tear down an Nginx server using Docker.

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
NGINX_BASE_DIR="/opt/nginx"

# --- Helper Functions for Clean Output ---
info() {
    printf "    %s" "$1"
}

success() {
    printf "Done.\n"
}

# --- Main Functions ---

install() {
    echo "🚀 Starting Nginx Docker Setup..."

    info "Creating Nginx directories..."
    mkdir -p "$NGINX_BASE_DIR"/{conf.d,log,ssl,html}
    success

    info "Creating docker-compose.yaml..."
    cat << 'EOF' > "$NGINX_BASE_DIR/docker-compose.yaml"
services:
  nginx:
    image: nginx:stable
    container_name: nginx
    network_mode: host
    restart: always
    environment:
      - TZ=Asia/Shanghai
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./log/:/var/log/nginx/
      - ./html/:/usr/share/nginx/html/
      - ./conf.d/:/etc/nginx/conf.d/
      - ./ssl/:/etc/nginx/ssl/
      - /etc/letsencrypt:/etc/letsencrypt:ro
EOF
    success

    info "Creating nginx.conf..."
    cat << 'EOF' > "$NGINX_BASE_DIR/nginx.conf"
user  nginx;
worker_processes  auto;
error_log  /var/log/nginx/error.log  info;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    server_tokens off;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access_log  main;

    sendfile        on;
    tcp_nopush      on;
    keepalive_timeout  65;
    gzip  on;

    include /etc/nginx/conf.d/*.conf;
}
EOF
    success

    info "Generating self-signed SSL certificate..."
    if [ ! -f "$NGINX_BASE_DIR/ssl/selfsigned.key" ]; then
      openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
        -keyout "$NGINX_BASE_DIR/ssl/selfsigned.key" \
        -out "$NGINX_BASE_DIR/ssl/selfsigned.crt" \
        -subj "/C=US/ST=California/L=SanFrancisco/O=MyOrg/OU=Dev/CN=localhost" > /dev/null 2>&1
      success
    else
      printf "Skipped (already exists).\n"
    fi

    info "Creating default.conf..."
    cat << 'EOF' > "$NGINX_BASE_DIR/conf.d/default.conf"
server {
    listen 80 default_server;
    listen 443 ssl default_server;
    
    ssl_certificate /etc/nginx/ssl/selfsigned.crt;
    ssl_certificate_key /etc/nginx/ssl/selfsigned.key;
    
    location / {
        return 200 'OK';
        add_header Content-Type text/plain;
    }
}
EOF
    success

    echo
    echo "🚀 Launching Nginx Container..."
    cd "$NGINX_BASE_DIR"
    docker compose pull -q
    docker compose up -d --force-recreate

    echo
    echo "✅ All done! Nginx is up and running."
    echo "   To check status: cd $NGINX_BASE_DIR && docker compose ps"
    echo "   To view logs:    docker compose logs -f"
}

uninstall() {
    echo "🔥 This will stop the Nginx container, remove its image, and permanently delete all files in $NGINX_BASE_DIR."
    read -p "   Are you sure you want to continue? [y/N] " -n 1 -r
    echo # Move to a new line

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Uninstall cancelled."
        exit 1
    fi

    if [ ! -d "$NGINX_BASE_DIR" ]; then
        echo "Directory $NGINX_BASE_DIR not found. Nothing to do."
        exit 0
    fi

    echo
    info "Stopping containers and removing images..."
    if [ -f "$NGINX_BASE_DIR/docker-compose.yaml" ]; then
        cd "$NGINX_BASE_DIR"
        # --rmi all removes the nginx:stable image as well
        docker compose down --volumes --rmi all
    fi
    success

    info "Removing Nginx directory: $NGINX_BASE_DIR..."
    cd ..
    rm -rf "$NGINX_BASE_DIR"
    success

    echo
    echo "✅ Uninstall complete."
}

# --- Script Entrypoint ---

case "$1" in
    --uninstall)
        uninstall
        ;;
    ""|--install)
        install
        ;;
    *)
        echo "Invalid argument: $1"
        echo "Usage: $0 [--install | --uninstall]"
        exit 1
        ;;
esac
