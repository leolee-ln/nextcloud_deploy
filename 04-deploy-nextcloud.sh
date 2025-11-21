#!/bin/bash
echo "=== 部署 Nextcloud 实例 ==="

# 拉取 Nextcloud 镜像
echo "拉取 Nextcloud 镜像..."
podman pull swr.cn-east-2.myhuaweicloud.com/library/nextcloud:latest

# 读取 MySQL 密码
MYSQL_PASSWORD=$(grep MYSQL_PASSWORD /data_raid1/containers/secrets/mysql-nextcloud.env | cut -d= -f2)

# 部署 Nextcloud（不设置管理员密码，后续在网页设置）
echo "启动 Nextcloud 容器..."
podman run -d \
  --name nextcloud \
  --restart unless-stopped \
  -p 8080:80 \
  -v /data_raid1/containers/nextcloud/data:/var/www/html/data:Z \
  -v /data_raid1/containers/nextcloud/config:/var/www/html/config:Z \
  -v /data_raid1/containers/nextcloud/apps:/var/www/html/apps:Z \
  -e NEXTCLOUD_ADMIN_USER=admin \
  -e NEXTCLOUD_TRUSTED_DOMAINS="localhost ic.ismd-nemo.xyz" \
  -e NEXTCLOUD_DB_TYPE=mysql \
  -e NEXTCLOUD_DB_NAME=nextcloud \
  -e NEXTCLOUD_DB_USER=nextcloud \
  -e NEXTCLOUD_DB_PASSWORD=$MYSQL_PASSWORD \
  -e NEXTCLOUD_DB_HOST=mysql \
  swr.cn-east-2.myhuaweicloud.com/library/nextcloud:latest

# 等待 Nextcloud 启动
echo "等待 Nextcloud 启动..."
sleep 30

# 验证服务
echo "验证 Nextcloud 服务..."
curl -f http://localhost:8080 > /dev/null 2>&1 && \
echo "Nextcloud 部署成功！" || echo "Nextcloud 启动失败，请检查日志"

echo "Nextcloud 访问地址:"
echo "http://ic.ismd-nemo.xyz:8080"
echo "http://localhost:8080"
echo ""
echo "请在首次访问时设置管理员密码"