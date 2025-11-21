#!/bin/bash
echo "=== 清理旧环境 ==="

# 停止并删除旧容器
podman stop nextcloud mysql 2>/dev/null
podman rm nextcloud mysql 2>/dev/null

# 备份并删除旧数据目录
if [ -d "/data_raid1/nextcloud" ]; then
    echo "备份旧数据到 /data_raid1/backup/..."
    sudo mkdir -p /data_raid1/backup
    sudo tar -czf /data_raid1/backup/nextcloud-old-$(date +%Y%m%d).tar.gz /data_raid1/nextcloud
    sudo rm -rf /data_raid1/nextcloud
fi

echo "清理完成！"