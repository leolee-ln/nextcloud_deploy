#!/bin/bash
echo "=== 安全密码设置 ==="

SECRETS_DIR="/data_raid1/containers/secrets"
sudo mkdir -p $SECRETS_DIR
sudo chmod 700 $SECRETS_DIR

# 生成随机密码
generate_password() {
    openssl rand -base64 16 | tr -d '/+=' | head -c 16
}

# 设置 MySQL root 密码
read -s -p "请输入 MySQL root 密码: " MYSQL_ROOT_PASSWORD
echo
echo "MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD" | sudo tee $SECRETS_DIR/mysql-root.env
echo "MYSQL_PASSWORD=$(generate_password)" | sudo tee $SECRETS_DIR/mysql-nextcloud.env

# 设置文件权限
sudo chmod 600 $SECRETS_DIR/*.env
sudo chown root:root $SECRETS_DIR/*.env

echo "密码文件已保存到: $SECRETS_DIR/"
echo "请妥善保管这些密码！"