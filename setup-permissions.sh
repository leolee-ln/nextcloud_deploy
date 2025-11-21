#!/bin/bash
echo "=== 设置脚本权限 ==="

chmod +x *.sh

echo "脚本权限设置完成！"
echo "执行顺序:"
echo "1. ./setup-permissions.sh    # 设置权限（当前步骤）"
echo "2. ./deploy-all.sh          # 一键部署所有服务"
echo "3. ./manage-services.sh status  # 检查服务状态"