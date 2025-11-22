#!/bin/bash
echo "=== 清理旧环境 ==="

# 停止并删除旧容器
MYSQL_CONTAINER_NAME=${MYSQL_CONTAINER_NAME:-mysql}
NEXTCLOUD_CONTAINER_NAME=${NEXTCLOUD_CONTAINER_NAME:-nextcloud}
podman stop "$NEXTCLOUD_CONTAINER_NAME" "$MYSQL_CONTAINER_NAME" 2>/dev/null || true
podman rm "$NEXTCLOUD_CONTAINER_NAME" "$MYSQL_CONTAINER_NAME" 2>/dev/null || true
podman network rm nextcloud-network 2>/dev/null || true

# 备份并删除旧数据目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/config.env" ]; then
    # shellcheck disable=SC1090
    . "$SCRIPT_DIR/config.env"
fi
DATA_DIR=${DATA_DIR:-/data_raid1/containers}
BACKUP_DIR="$(dirname "$DATA_DIR")/backup"
if [ -d "$DATA_DIR" ]; then
        echo "备份旧数据到 $BACKUP_DIR/..."
        mkdir -p "$BACKUP_DIR"
        tar -czf "$BACKUP_DIR"/containers-old-$(date +%Y%m%d).tar.gz "$DATA_DIR"/
        rm -rf "$DATA_DIR"/
fi

echo "清理完成！"