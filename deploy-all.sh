#!/bin/bash
echo "=== Nextcloud + MySQL 一键部署 ==="
echo "域名: ic.ismd-nemo.xyz"
echo ""

# 执行顺序
scripts=(
    "00-cleanup.sh"
    "01-init-directories.sh" 
    "02-setup-secrets.sh"
    "03-deploy-mysql.sh"
    "04-deploy-nextcloud.sh"
)

for script in "${scripts[@]}"; do
    if [ -f "$script" ]; then
        echo "执行: $script"
        bash "$script"
        if [ $? -ne 0 ]; then
            echo "错误: $script 执行失败"
            exit 1
        fi
        echo ""
    else
        echo "警告: 找不到脚本 $script"
    fi
done

echo "=== 部署完成 ==="
echo ""
echo "访问信息:"
echo "Nextcloud: http://ic.ismd-nemo.xyz:8080 或 http://服务器IP:8080"
echo "MySQL: 端口 3306"
echo ""
echo "首次访问 Nextcloud 时请设置管理员密码"
echo "MySQL root 密码保存在安全位置"