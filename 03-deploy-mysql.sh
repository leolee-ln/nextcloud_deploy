#!/bin/bash
echo "=== 部署 MySQL 实例 ==="

# 拉取 MySQL 镜像
echo "拉取 MySQL 镜像..."
podman pull swr.cn-north-1.myhuaweicloud.com/library/mysql:8.0

# 读取密码
MYSQL_ROOT_PASSWORD=$(grep MYSQL_ROOT_PASSWORD /data_raid1/containers/secrets/mysql-root.env | cut -d= -f2)
MYSQL_PASSWORD=$(grep MYSQL_PASSWORD /data_raid1/containers/secrets/mysql-nextcloud.env | cut -d= -f2)

# 部署 MySQL
echo "启动 MySQL 容器..."
podman run -d \
  --name mysql \
  --restart unless-stopped \
  -p 3306:3306 \
  -v /data_raid1/containers/mysql/data:/var/lib/mysql:Z \
  -v /data_raid1/containers/mysql/config:/etc/mysql/conf.d:Z \
  -v /data_raid1/containers/mysql/logs:/var/log/mysql:Z \
  -e MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD \
  -e MYSQL_DATABASE=nextcloud \
  -e MYSQL_USER=nextcloud \
  -e MYSQL_PASSWORD=$MYSQL_PASSWORD \
  swr.cn-north-1.myhuaweicloud.com/library/mysql:8.0

# 等待 MySQL 启动
echo "等待 MySQL 启动..."
sleep 30

# 验证 MySQL 连接
echo "验证 MySQL 连接..."
podman exec mysql mysql -u root -p$MYSQL_ROOT_PASSWORD -e "SHOW DATABASES;" && \
echo "MySQL 部署成功！" || echo "MySQL 连接失败，请检查日志"

echo "MySQL 容器名称: mysql"
echo "MySQL 端口: 3306"
echo "Nextcloud 数据库: nextcloud"