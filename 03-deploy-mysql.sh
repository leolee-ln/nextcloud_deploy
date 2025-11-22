#!/bin/bash
echo "=== 部署 MySQL 实例 ==="

# Load configuration if present
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/config.env" ]; then
  # shellcheck disable=SC1090
  . "$SCRIPT_DIR/config.env"
fi
MYSQL_CONTAINER_NAME=${MYSQL_CONTAINER_NAME:-mysql}

# 拉取 MySQL 镜像
echo "拉取 MySQL 镜像..."
podman pull swr.cn-north-1.myhuaweicloud.com/library/mysql:8.0

# 读取密码
# MYSQL_ROOT_PASSWORD=$(grep MYSQL_ROOT_PASSWORD "$DATA_DIR"/secrets/mysql-root.env | cut -d= -f2)
MYSQL_PASSWORD=$(grep MYSQL_PASSWORD "$DATA_DIR"/secrets/mysql-nextcloud.env | cut -d= -f2)

# 设置 MySQL root 密码（输入并确认）
while true; do
  read -s -p "请输入 MySQL root 密码: " MYSQL_ROOT_PASSWORD
  echo
  read -s -p "请再次输入 MySQL root 密码以确认: " MYSQL_ROOT_PASSWORD_CONFIRM
  echo
  if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
    echo "密码不能为空，请重试。"
    continue
  fi
  if [ "$MYSQL_ROOT_PASSWORD" = "$MYSQL_ROOT_PASSWORD_CONFIRM" ]; then
    break
  else
    echo "两次输入的密码不匹配，请重试。"
  fi
done

# 创建 MySQL 配置文件
[ -d "$DATA_DIR/mysql/config" ] || mkdir -p "$DATA_DIR/mysql/config"
cat > "$DATA_DIR/mysql/config/custom.cnf" <<'EOF'
[mysqld]
default_authentication_plugin=mysql_native_password
bind-address = 0.0.0.0
skip-name-resolve

[client]
default-auth=mysql_native_password
EOF

# 停止并清理旧容器
podman stop "$MYSQL_CONTAINER_NAME" 2>/dev/null || true
podman rm "$MYSQL_CONTAINER_NAME" 2>/dev/null || true

# 部署 MySQL
echo "启动 MySQL 容器..."

# Prepare optional host port mapping for MySQL
MYSQL_PORT_ARGS=()
if [ -n "$MYSQL_EXPOSE_PORT" ]; then
  MYSQL_PORT_ARGS=( -p "$MYSQL_EXPOSE_PORT":3306 )
fi

podman run -d \
  --name "$MYSQL_CONTAINER_NAME" \
  --network nextcloud-network \
  --restart unless-stopped \
  "${MYSQL_PORT_ARGS[@]}" \
  -v "$DATA_DIR"/mysql/data:/var/lib/mysql:Z \
  -v "$DATA_DIR"/mysql/config:/etc/mysql/conf.d:Z \
  -v "$DATA_DIR"/mysql/logs:/var/log/mysql:Z \
  -e MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD" \
  -e MYSQL_DATABASE=nextcloud \
  -e MYSQL_USER=nextcloud \
  -e MYSQL_PASSWORD="$MYSQL_PASSWORD" \
  -e MYSQL_DEFAULT_AUTHENTICATION_PLUGIN=mysql_native_password \
  swr.cn-north-1.myhuaweicloud.com/library/mysql:8.0

# 等待 MySQL 启动
echo "等待 MySQL 启动..."
sleep 30

# 验证 MySQL 连接
echo "验证 MySQL 连接..."
podman exec "$MYSQL_CONTAINER_NAME" mysql -u root -p$MYSQL_ROOT_PASSWORD -e "SHOW DATABASES;" && \
echo "MySQL 部署成功！" || echo "MySQL 连接失败，请检查日志"

echo "MySQL 容器名称: $MYSQL_CONTAINER_NAME"
if [ -n "$MYSQL_EXPOSE_PORT" ]; then
  echo "MySQL 外部端口: $MYSQL_EXPOSE_PORT"
else
  echo "MySQL 未暴露外部端口（仅容器内可访问）"
fi
echo "Nextcloud 数据库: nextcloud"

# 修改认证插件
echo "修改 nextcloud 用户认证插件..."
podman exec "$MYSQL_CONTAINER_NAME" mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "
ALTER USER 'nextcloud'@'%' IDENTIFIED WITH mysql_native_password BY '$MYSQL_PASSWORD';
FLUSH PRIVILEGES;
"

# 验证修改
echo "验证 nextcloud 用户认证插件修改..."
podman exec "$MYSQL_CONTAINER_NAME" mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT user, host, plugin FROM mysql.user WHERE user='nextcloud';"