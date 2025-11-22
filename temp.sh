# 获取密码
MYSQL_ROOT_PASSWORD=$(grep MYSQL_ROOT_PASSWORD /data_raid1/containers/secrets/mysql-root.env | cut -d= -f2)
MYSQL_PASSWORD="Gc1M1C1TEKRij00x"

# 修改认证插件
podman exec mysql mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "
ALTER USER 'nextcloud'@'%' IDENTIFIED WITH mysql_native_password BY '$MYSQL_PASSWORD';
FLUSH PRIVILEGES;
"

# 验证修改
podman exec mysql mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT user, host, plugin FROM mysql.user WHERE user='nextcloud';"