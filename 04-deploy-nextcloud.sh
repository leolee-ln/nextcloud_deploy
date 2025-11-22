#!/bin/bash
echo "=== 部署 Nextcloud 实例 ==="

# 拉取 Nextcloud 镜像
podman pull swr.cn-east-2.myhuaweicloud.com/library/nextcloud:latest

# 读取 MySQL 密码
MYSQL_PASSWORD=$(grep MYSQL_PASSWORD /data_raid1/containers/secrets/mysql-nextcloud.env | cut -d= -f2)

# 生成 SSL 证书（如果不存在）
if [ ! -f "/data_raid1/containers/nextcloud/ssl/nextcloud.crt" ]; then
    echo "生成 SSL 证书..."
    sudo mkdir -p /data_raid1/containers/nextcloud/ssl
    cd /data_raid1/containers/nextcloud/ssl
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout nextcloud.key -out nextcloud.crt \
      -subj "/C=CN/ST=Beijing/L=Beijing/O=YourOrganization/CN=ic.ismd-nemo.xyz"
    sudo chown 1000:1000 nextcloud.key nextcloud.crt
fi

# 停止并清理旧容器
podman stop nextcloud 2>/dev/null
podman rm nextcloud 2>/dev/null

# 设置 Nextcloud 管理员
read -p "请输入 Nextcloud 管理员用户名 (默认: admin): " NC_ADMIN_USER
NC_ADMIN_USER=${NC_ADMIN_USER:-admin}
read -s -p "请输入 Nextcloud 管理员密码: " NC_ADMIN_PASSWORD
echo

# 部署 Nextcloud
echo "启动 Nextcloud 容器..."
podman run -d \
  --name nextcloud \
  --network nextcloud-network \
  -p 8443:443 \
  -v /data_raid1/containers/nextcloud/data:/var/www/html/data:Z \
  -v /data_raid1/containers/nextcloud/config:/var/www/html/config:Z \
  -v /data_raid1/containers/nextcloud/apps:/var/www/html/apps:Z \
  -v /data_raid1/containers/nextcloud/ssl:/etc/ssl/private:Z \
  -e NEXTCLOUD_ADMIN_USER=$NC_ADMIN_USER \
  -e NEXTCLOUD_ADMIN_PASSWORD=$NC_ADMIN_PASSWORD \
  -e NEXTCLOUD_TRUSTED_DOMAINS="ic.ismd-nemo.xyz localhost" \
  -e OVERWRITECLIURL="https://ic.ismd-nemo.xyz:8443" \
  -e NEXTCLOUD_DB_TYPE=mysql \
  -e NEXTCLOUD_DB_NAME=nextcloud \
  -e NEXTCLOUD_DB_USER=nextcloud \
  -e NEXTCLOUD_DB_PASSWORD=$MYSQL_PASSWORD \
  -e NEXTCLOUD_DB_HOST=mysql:3306 \
  -e OVERWRITEPROTOCOL="https" \
  swr.cn-east-2.myhuaweicloud.com/library/nextcloud:latest

# 等待启动
echo "等待服务启动..."
sleep 15

# 配置 SSL
echo "配置 SSL..."
podman exec nextcloud bash -c "
  a2enmod ssl headers rewrite && \
  cat > /etc/apache2/sites-available/nextcloud-ssl.conf << 'EOF'
<VirtualHost *:443>
  ServerName ic.ismd-nemo.xyz
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

echo "等待 SSL 配置生效..."
sleep 10

# 验证服务
echo "验证 Nextcloud 服务..."
if curl -k -s https://localhost:8443 > /dev/null; then
    echo "Nextcloud HTTPS 部署成功!"
    echo "访问地址: https://ic.ismd-nemo.xyz:8443"
else
    echo "部署失败，查看日志: podman logs nextcloud"
fi

echo "Nextcloud 访问地址:"
echo "https://ic.ismd-nemo.xyz:8443"
echo "https://localhost:8443"
echo ""
echo "请在首次访问时设置管理员密码"