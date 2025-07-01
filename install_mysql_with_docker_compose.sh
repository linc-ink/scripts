#!/bin/bash
# 如果任何命令失败，脚本将立即退出
set -e

# --- 配置 ---
# 主工作目录
MYSQL_HOME="/opt/mysql"
# Compose 文件路径
COMPOSE_FILE="$MYSQL_HOME/docker-compose.yaml"
# 配置文件目录
CONF_DIR="$MYSQL_HOME/conf.d"
# 数据持久化目录
DATA_DIR="$MYSQL_HOME/data"

# --- 欢迎信息 ---
echo "欢迎使用 MySQL (LTS) Docker Compose 安装脚本。"
echo "此脚本将在 $MYSQL_HOME 中创建所有必需的文件。"
echo "----------------------------------------------------"

# --- 1. 询问用户输入容器名 ---
read -p "请输入您希望的 Docker 容器名称 (默认为: mysql-lts): " CONTAINER_NAME
# 如果用户未输入，则使用默认值
if [ -z "$CONTAINER_NAME" ]; then
    CONTAINER_NAME="mysql-lts"
fi
echo "容器名称将设置为: $CONTAINER_NAME"
echo ""

# --- 2. 创建目录结构 ---
echo "正在创建工作目录..."
mkdir -p "$CONF_DIR"
mkdir -p "$DATA_DIR"
# 设置数据目录权限，确保 mysql 用户可以写入
# chown -R 999:999 "$DATA_DIR"
echo "目录 $MYSQL_HOME, $CONF_DIR, $DATA_DIR 已创建。"
echo ""

# --- 3. 生成随机密码 ---
# 使用 OpenSSL 生成一个安全的16位随机密码
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 12)
echo "已为您生成一个安全的 root 密码。"
echo ""

# --- 4. 创建优化配置文件 ---
echo "正在生成 MySQL 优化配置文件 (optimized.cnf)..."
cat <<EOF > "$CONF_DIR/optimized.cnf"
[mysqld]
# 字符集设置
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci

# InnoDB 缓冲池大小，可根据服务器内存调整 (例如 512M, 1G)
innodb_buffer_pool_size=512M

# 最大连接数
max_connections=200

# 其他优化
connect_timeout=10
skip-name-resolve
EOF
echo "配置文件已创建于 $CONF_DIR/optimized.cnf"
echo ""

# --- 5. 创建 docker-compose.yaml 文件 ---
echo "正在生成 docker-compose.yaml 文件..."
# 使用 cat 和 EOF 来写入多行文本
cat <<EOF > "$COMPOSE_FILE"
version: '3.8'

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
    command:
      --default-authentication-plugin=mysql_native_password

networks:
  default:
    name: mysql_network
EOF
echo "docker-compose.yaml 已创建于 $COMPOSE_FILE"
echo ""

# --- 6. 启动容器 ---
echo "准备就绪！正在 $MYSQL_HOME 目录中启动 MySQL 容器..."
# 切换到工作目录并启动 docker-compose
cd "$MYSQL_HOME"
# 将变量导出，以便 docker-compose 可以访问
export CONTAINER_NAME
docker-compose up -d

# --- 7. 显示最终信息 ---
echo ""
echo "🎉 MySQL 容器已成功启动！"
echo "----------------------------------------------------"
echo "以下是您的连接信息:"
echo "  主机 (Host): 127.0.0.1"
echo "  端口 (Port): 3306"
echo "  用户 (User): root"
echo "  密码 (Password): $MYSQL_ROOT_PASSWORD"
echo ""
echo "重要提示:"
echo "  - 数据库文件持久化在: $DATA_DIR"
echo "  - 配置文件位于: $CONF_DIR"
echo "  - 您可以使用以下命令连接到数据库:"
echo "    mysql -h 127.0.0.1 -P 3306 -u root -p"
echo "  - 如需停止服务，请在 $MYSQL_HOME 目录下运行: docker-compose down"
echo "----------------------------------------------------"

