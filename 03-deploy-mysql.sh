#!/bin/bash
echo "=== 部署 MySQL 实例 ==="

# 拉取 MySQL 镜像
echo "拉取 MySQL 镜像..."
podman pull swr.cn-north-1.myhuaweicloud.com/library/mysql:8.0

# 读取密码
# MYSQL_ROOT_PASSWORD=$(grep MYSQL_ROOT_PASSWORD /data_raid1/containers/secrets/mysql-root.env | cut -d= -f2)
MYSQL_PASSWORD=$(grep MYSQL_PASSWORD /data_raid1/containers/secrets/mysql-nextcloud.env | cut -d= -f2)

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
sudo tee /data_raid1/containers/mysql/config/custom.cnf > /dev/null <<'EOF'
[mysqld]
default_authentication_plugin=mysql_native_password
bind-address = 0.0.0.0
skip-name-resolve

[client]
default-auth=mysql_native_password
EOF

# 部署 MySQL
echo "启动 MySQL 容器..."
podman run -d \
  --name mysql \
  --network nextcloud-network \
  --restart unless-stopped \
  -p 3306:3306 \
  -v /data_raid1/containers/mysql/data:/var/lib/mysql:Z \
  -v /data_raid1/containers/mysql/config:/etc/mysql/conf.d:Z \
  -v /data_raid1/containers/mysql/logs:/var/log/mysql:Z \
  -e MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD \
  -e MYSQL_DATABASE=nextcloud \
  -e MYSQL_USER=nextcloud \
  -e MYSQL_PASSWORD=$MYSQL_PASSWORD \
  -e MYSQL_DEFAULT_AUTHENTICATION_PLUGIN=mysql_native_password \
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

# 修改认证插件
echo "修改 nextcloud 用户认证插件..."
podman exec mysql mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "
ALTER USER 'nextcloud'@'%' IDENTIFIED WITH mysql_native_password BY '$MYSQL_PASSWORD';
FLUSH PRIVILEGES;
"

# 验证修改
echo "验证 nextcloud 用户认证插件修改..."
podman exec mysql mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT user, host, plugin FROM mysql.user WHERE user='nextcloud';"