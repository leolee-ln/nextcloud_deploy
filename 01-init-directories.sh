#!/bin/bash
echo "=== 初始化目录结构和 SELinux ==="

# 创建基础目录结构
sudo mkdir -p /data_raid1/containers/{nextcloud,mysql,backups}
sudo mkdir -p /data_raid1/containers/nextcloud/{data,config,apps,ssl}
sudo mkdir -p /data_raid1/containers/mysql/{data,config,logs}

# 设置目录权限
echo "设置目录权限..."
sudo chmod 755 /data_raid1/containers
sudo find /data_raid1/containers -type d -exec chmod 755 {} \;

# 设置 SELinux 上下文
echo "配置 SELinux 上下文..."
sudo semanage fcontext -a -t container_file_t "/data_raid1/containers(/.*)?" 2>/dev/null || true
sudo restorecon -R -v /data_raid1/containers

# 设置特定所有权
sudo chown -R 1000:1000 /data_raid1/containers/nextcloud/
sudo chown -R 27:27 /data_raid1/containers/mysql/  # MySQL 默认使用 UID 27

echo "目录结构初始化完成！"
echo "路径: /data_raid1/containers/"
echo "SELinux 上下文: container_file_t"

echo "创建自定义网络..."
podman network create nextcloud-network || echo "网络已存在，跳过创建。"