#!/bin/bash
echo "=== 容器服务管理 ==="

# Load configuration if present
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/config.env" ]; then
    # shellcheck disable=SC1090
    . "$SCRIPT_DIR/config.env"
fi
DATA_DIR=${DATA_DIR:-/data_raid1/containers}

case "$1" in
    start)
        echo "启动所有服务..."
        podman start mysql nextcloud
        ;;
    stop)
        echo "停止所有服务..."
        podman stop nextcloud mysql
        ;;
    restart)
        echo "重启所有服务..."
        podman restart mysql nextcloud
        ;;
    status)
        echo "服务状态:"
        podman ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo -e "\n资源使用:"
        podman stats --no-stream
        ;;
    logs)
        echo "服务日志:"
        podman logs --tail 20 $2
        ;;
    backup)
        echo "备份数据..."
        mkdir -p "$DATA_DIR/backups"
        tar -czf "$DATA_DIR/backups/backup-$(date +%Y%m%d).tar.gz" "$DATA_DIR/nextcloud" "$DATA_DIR/mysql"
        echo "备份完成: $DATA_DIR/backups/backup-$(date +%Y%m%d).tar.gz"
        ;;
    update)
        echo "更新服务..."
        bash 00-cleanup.sh
        podman pull mysql:8.0
        podman pull swr.cn-east-2.myhuaweicloud.com/library/nextcloud:latest
        bash 03-deploy-mysql.sh
        bash 04-deploy-nextcloud.sh
        ;;
    *)
        echo "用法: $0 {start|stop|restart|status|logs [服务名]|backup|update}"
        echo "示例:"
        echo "  $0 start      # 启动所有服务"
        echo "  $0 status     # 查看状态"
        echo "  $0 logs mysql # 查看 MySQL 日志"
        echo "  $0 backup     # 备份数据"
        exit 1
        ;;
esac