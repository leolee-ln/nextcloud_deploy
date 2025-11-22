#!/bin/bash
echo "=== 安全密码设置 ==="

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/config.env" ]; then
    # shellcheck disable=SC1090
    . "$SCRIPT_DIR/config.env"
fi
DATA_DIR=${DATA_DIR:-/data_raid1/containers}
SECRETS_DIR="$DATA_DIR/secrets"
mkdir -p "$SECRETS_DIR"
chmod 700 "$SECRETS_DIR"

# 生成随机密码
generate_password() {
    openssl rand -base64 16 | tr -d '/+=' | head -c 16
}

# # 设置 MySQL root 密码
# read -s -p "请输入 MySQL root 密码: " MYSQL_ROOT_PASSWORD
# echo
# echo "MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD" | tee $SECRETS_DIR/mysql-root.env
echo "MYSQL_PASSWORD=$(generate_password)" | tee "$SECRETS_DIR"/mysql-nextcloud.env

# 设置文件权限
chmod 600 "$SECRETS_DIR"/*.env
chown root:root "$SECRETS_DIR"/*.env

echo "密码文件已保存到: $SECRETS_DIR/"
echo "请妥善保管这些密码！"