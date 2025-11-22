#!/bin/bash
echo "=== 部署 Nextcloud 实例 ==="

# Load configuration if present
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/config.env" ]; then
  # shellcheck disable=SC1090
  . "$SCRIPT_DIR/config.env"
fi

# 拉取 Nextcloud 镜像
podman pull swr.cn-east-2.myhuaweicloud.com/library/nextcloud:latest

# 读取 MySQL 密码
MYSQL_PASSWORD=$(grep MYSQL_PASSWORD "$DATA_DIR"/secrets/mysql-nextcloud.env | cut -d= -f2)

# 生成 SSL 证书（如果不存在）
if [ ! -f "$DATA_DIR/nextcloud/ssl/nextcloud.crt" ]; then
    echo "生成 SSL 证书..."
    mkdir -p "$DATA_DIR/nextcloud/ssl"
    cd "$DATA_DIR/nextcloud/ssl" || exit 1
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout nextcloud.key -out nextcloud.crt \
      -subj "/C=CN/ST=Beijing/L=Beijing/O=YourOrganization/CN=${NEXTCLOUD_DOMAIN}"
    chown 1000:1000 nextcloud.key nextcloud.crt
fi

# 停止并清理旧容器
podman stop nextcloud 2>/dev/null
podman rm nextcloud 2>/dev/null

# 设置 Nextcloud 管理员
read -p "请输入 Nextcloud 管理员用户名 (默认: admin): " NC_ADMIN_USER
NC_ADMIN_USER=${NC_ADMIN_USER:-admin}

# 设置 Nextcloud 管理员密码（输入并确认）
while true; do
  read -s -p "请输入 Nextcloud 管理员密码: " NC_ADMIN_PASSWORD
  echo
  read -s -p "请再次输入 Nextcloud 管理员密码以确认: " NC_ADMIN_PASSWORD_CONFIRM
  echo
  if [ -z "$NC_ADMIN_PASSWORD" ]; then
    echo "密码不能为空，请重试。"
    continue
  fi
  if [ "$NC_ADMIN_PASSWORD" = "$NC_ADMIN_PASSWORD_CONFIRM" ]; then
    break
  else
    echo "两次输入的密码不匹配，请重试。"
  fi
done

# # debug
# echo "Nextcloud 管理员用户名: $NC_ADMIN_USER"
# echo "Nextcloud 管理员密码: $NC_ADMIN_PASSWORD"

# 清理旧的配置和数据（确保重新安装）
echo "清理旧配置..."
rm -rf "$DATA_DIR"/nextcloud/config/*
rm -rf "$DATA_DIR"/nextcloud/data/*

# 首先启动一个基础容器（不自动安装）
echo "启动 Nextcloud 基础容器..."

# Ensure Nextcloud directories exist
mkdir -p "$DATA_DIR"/nextcloud/{data,config,apps,ssl}

podman run -d \
  --name nextcloud \
  --network nextcloud-network \
  -p ${NEXTCLOUD_PORT}:443 \
  -v "$DATA_DIR"/nextcloud/data:/var/www/html/data:Z \
  -v "$DATA_DIR"/nextcloud/config:/var/www/html/config:Z \
  -v "$DATA_DIR"/nextcloud/apps:/var/www/html/apps:Z \
  -v "$DATA_DIR"/nextcloud/ssl:/etc/ssl/private:Z \
  -e NEXTCLOUD_TRUSTED_DOMAINS="${NEXTCLOUD_DOMAIN} localhost" \
  -e OVERWRITECLIURL="https://${NEXTCLOUD_DOMAIN}:${NEXTCLOUD_PORT}" \
  -e OVERWRITEPROTOCOL="https" \
  swr.cn-east-2.myhuaweicloud.com/library/nextcloud:latest

# 等待启动
echo "等待服务启动..."
sleep 30

# 配置 SSL
echo "配置 SSL..."
podman exec nextcloud bash -c "
  a2enmod ssl headers rewrite && \
  cat > /etc/apache2/sites-available/nextcloud-ssl.conf << 'EOF'
<VirtualHost *:443>
  ServerName ${NEXTCLOUD_DOMAIN}
  DocumentRoot /var/www/html
  SSLEngine on
  SSLCertificateFile /etc/ssl/private/nextcloud.crt
  SSLCertificateKeyFile /etc/ssl/private/nextcloud.key
  <Directory /var/www/html/>
    Options +FollowSymlinks
    AllowOverride All
    Require all granted
  </Directory>
</VirtualHost>
EOF
  a2dissite 000-default.conf 2>/dev/null
  a2ensite nextcloud-ssl.conf
  apache2ctl graceful
"

# 等待 SSL 配置生效
sleep 10

# 使用 occ 命令手动安装
echo "使用 occ 命令配置 Nextcloud..."
podman exec --user www-data nextcloud php /var/www/html/occ maintenance:install \
  --database "mysql" \
  --database-name "nextcloud" \
  --database-user "nextcloud" \
  --database-pass "$MYSQL_PASSWORD" \
  --database-host "mysql:3306" \
  --admin-user "$NC_ADMIN_USER" \
  --admin-pass "$NC_ADMIN_PASSWORD" \
  --data-dir "/var/www/html/data"

# 配置信任域名和覆盖 URL
echo "配置信任域名..."
podman exec --user www-data nextcloud php /var/www/html/occ config:system:set trusted_domains 1 --value="${NEXTCLOUD_DOMAIN}"
podman exec --user www-data nextcloud php /var/www/html/occ config:system:set overwrite.cli.url --value="https://${NEXTCLOUD_DOMAIN}:${NEXTCLOUD_PORT}"
podman exec --user www-data nextcloud php /var/www/html/occ config:system:set overwriteprotocol --value="https"

# 重启 Apache 使所有配置生效
podman exec nextcloud apache2ctl graceful

# 验证服务
echo "验证 Nextcloud 服务..."
if curl -k -s https://localhost:${NEXTCLOUD_PORT} > /dev/null; then
  echo "Nextcloud HTTPS 部署成功!"
  echo "访问地址: https://${NEXTCLOUD_DOMAIN}:${NEXTCLOUD_PORT}"
    
    # # debug 检查配置是否包含数据库设置
    # echo "检查数据库配置..."
    # podman exec nextcloud cat /var/www/html/config/config.php | grep db
else
    echo "部署失败，查看日志: podman logs nextcloud"
fi

echo "Nextcloud 访问地址:"
echo "https://${NEXTCLOUD_DOMAIN}:${NEXTCLOUD_PORT}"
echo "https://localhost:${NEXTCLOUD_PORT}"