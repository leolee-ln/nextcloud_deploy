#!/bin/bash
echo "=== 初始化目录结构和 SELinux ==="

# Load configuration if present
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/config.env" ]; then
	# shellcheck disable=SC1090
	. "$SCRIPT_DIR/config.env"
fi
DATA_DIR=${DATA_DIR:-/data_raid1/containers}

# 创建基础目录结构
mkdir -p "$DATA_DIR"/{nextcloud,mysql,backups}
mkdir -p "$DATA_DIR"/nextcloud/{data,config,apps,ssl}
mkdir -p "$DATA_DIR"/mysql/{data,config,logs}

# 设置目录权限
echo "设置目录权限..."
chmod 755 "$DATA_DIR"
find "$DATA_DIR" -type d -exec chmod 755 {} \;

# 设置 SELinux 上下文
echo "配置 SELinux 上下文..."
semanage fcontext -a -t container_file_t "$DATA_DIR(/.*)?" 2>/dev/null || true
restorecon -R -v "$DATA_DIR"

# 设置特定所有权
chown -R 1000:1000 "$DATA_DIR"/nextcloud/
chown -R 27:27 "$DATA_DIR"/mysql/  # MySQL 默认使用 UID 27

echo "目录结构初始化完成！"
echo "路径: $DATA_DIR/"
echo "SELinux 上下文: container_file_t"

echo "创建自定义网络..."
podman network create nextcloud-network || echo "网络已存在，跳过创建。"