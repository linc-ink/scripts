#!/bin/bash
# exit when any command fails
set -e

# --- Configuration ---
MYSQL_HOME="/opt/mysql"
COMPOSE_FILE="$MYSQL_HOME/docker-compose.yaml"
CONF_DIR="$MYSQL_HOME/conf.d"
DATA_DIR="$MYSQL_HOME/data"
CONTAINER_NAME="mysql"

# --- Dependency Check ---
check_dependencies() {
    if ! command -v docker &> /dev/null; then
        echo "Error: Docker is not installed." >&2
        exit 1
    fi
    if docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
    elif command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    else
        echo "Error: Docker Compose not found." >&2
        exit 1
    fi
}

# --- Main Execution ---
# 1. Clean up previous failed installation
sudo docker rm -f "$CONTAINER_NAME" &>/dev/null || true
sudo rm -rf "$MYSQL_HOME"

# 2. Run dependency check
check_dependencies

# 3. Create directory structure
mkdir -p "$CONF_DIR"
mkdir -p "$DATA_DIR"

# 4. Generate a secure root password
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 12)

# 5. Create optimized.cnf
cat <<EOF > "$CONF_DIR/optimized.cnf"
[mysqld]
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci
innodb_buffer_pool_size=256M
max_connections=200
connect_timeout=10
skip-name-resolve
EOF

# 6. Create docker-compose.yaml
cat <<EOF > "$COMPOSE_FILE"
services:
  mysql:
    image: mysql:lts
    container_name: ${CONTAINER_NAME}
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: '${MYSQL_ROOT_PASSWORD}'
      TZ: 'Asia/Shanghai'
    ports:
      - "3306:3306"
    volumes:
      - ./data:/var/lib/mysql
      - ./conf.d:/etc/mysql/conf.d
EOF

# 7. Start the container
cd "$MYSQL_HOME"
export CONTAINER_NAME
$COMPOSE_CMD up -d &>/dev/null

# --- Final Output ---
cat <<EOF
----------------------------------------------------
MySQL container started successfully!

Host: 127.0.0.1
Port: 3306
User: root
Password: ${MYSQL_ROOT_PASSWORD}

To stop: cd ${MYSQL_HOME} && ${COMPOSE_CMD} down
----------------------------------------------------
EOF
