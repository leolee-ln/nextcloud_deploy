# nextcloud_deploy
# nextcloud_deploy

**简介**
- 本仓库提供一组用于使用 `podman` 在 Linux 主机上部署 Nextcloud 与 MySQL 的脚本集合，包含目录初始化、secrets 管理、容器部署与简单运维工具。

**设计要点**
- 脚本以可配置为原则，使用仓库根目录下的 `config.env` 来集中配置路径、端口、域名与容器实例名。
- 默认不在脚本内部强制使用 `sudo`；运行前请确保 `DATA_DIR`（默认为 `/data_raid1/containers`）对运行用户可写，或者用 `sudo` 提升权限执行初始化。

**先决条件**
- 操作系统: Linux
- 容器运行时: `podman` 已安装并可用
- 常用命令: `sh`/`bash`, `stty`, `grep`, `cut`, `tee`, `cat`, `openssl`
- SELinux: 若启用，请保留容器卷的 `:Z` 标记（脚本已使用 `:Z`）。

**配置文件（`config.env`）**
仓库根目录包含 `config.env` 示例，用于集中配置：

```
# 基础数据目录
DATA_DIR=/data_raid1/containers

# Nextcloud 对外端口（主机）
NEXTCLOUD_PORT=8443

# Nextcloud 域名（用于 trusted_domains 与证书 CN）
NEXTCLOUD_DOMAIN=ic.ismd-nemo.xyz

# 可选：将 MySQL 映射到宿主机端口（留空表示不暴露）
MYSQL_EXPOSE_PORT=

# 容器实例名称（可自定义）
MYSQL_CONTAINER_NAME=mysql
NEXTCLOUD_CONTAINER_NAME=nextcloud
```

编辑 `config.env` 后，所有脚本会自动读取并使用这些值（脚本优先从 `config.env` 读取，否则使用内置默认值）。

**脚本清单与说明**
- `00-cleanup.sh`：停止/移除容器、备份并删除数据目录（会读取 `DATA_DIR`）。
- `01-init-directories.sh`：创建目录树、设置 SELinux 上下文与基本权限并创建 `nextcloud-network`。
- `02-setup-secrets.sh`：生成或提示创建 secrets（写入 `$DATA_DIR/secrets/*.env`），并设置合适权限。
- `03-deploy-mysql.sh`：部署 MySQL 容器（可选把 MySQL 映射到宿主机端口，通过 `MYSQL_EXPOSE_PORT` 控制）。
- `04-deploy-nextcloud.sh`：部署 Nextcloud 容器，生成自签名证书（可替换为真实证书），并使用 `occ` 安装 Nextcloud。
- `manage-services.sh`：启动/停止/重启/查询/备份等管理操作。

**快速开始（交互式）**
1. 克隆仓库并进入：
```
git clone <repo> && cd nextcloud_deploy
```
2. 根据需要编辑 `config.env`（默认为仓库已提供值）：
```
vi config.env
```
3. 初始化目录（若 `DATA_DIR` 需要 root 权限，请用 `sudo` 执行）：
```
sh 01-init-directories.sh
```
4. 生成 secrets（会写入 `$DATA_DIR/secrets/mysql-nextcloud.env`）：
```
sh 02-setup-secrets.sh
```
5. 部署 MySQL（脚本会提示输入 root 密码并可选性暴露端口）：
```
sh 03-deploy-mysql.sh
```
6. 部署 Nextcloud：
```
sh 04-deploy-nextcloud.sh
```

**自动化运行（交互式）**
```
sh deploy-all.sh
```

**关于容器间连接**
- 脚本通过 `podman network create nextcloud-network` 创建自定义网络，并在 `podman run` 时把容器加入该网络。容器内服务可以通过容器名互相解析（例如 `mysql:3306` 或 `${MYSQL_CONTAINER_NAME}:3306`）。

**MySQL 暴露到宿主机**
- 默认情况下 MySQL 不会暴露到宿主机（`config.env` 中 `MYSQL_EXPOSE_PORT` 为空）。要允许宿主机或外部访问 MySQL，请在 `config.env` 中设置例如 `MYSQL_EXPOSE_PORT=3306`，然后重新运行 `03-deploy-mysql.sh`。

**权限与常见问题**
- 若脚本报错与文件写入相关，请检查 `$DATA_DIR` 的权限：
```
ls -ld "$DATA_DIR"
```
若需要将目录归当前用户：
```
sudo chown -R "$(id -u):$(id -g)" "$DATA_DIR"
```
- 若使用 SELinux，保留容器卷的 `:Z` 标记（脚本中已使用）。
- 隐藏输入后终端不回显：运行 `stty echo` 即可恢复。

**调试与常用命令**
- 查看容器： `podman ps -a`
- 查看日志： `podman logs <container-name>`（例如 `podman logs $NEXTCLOUD_CONTAINER_NAME`）
- 查看 MySQL 配置： `cat "$DATA_DIR"/mysql/config/custom.cnf`
- 手动执行 `occ` 命令：
```
podman exec --user www-data $NEXTCLOUD_CONTAINER_NAME php /var/www/html/occ status
```

**安全建议**
- 在自动化环境（CI）中避免交互式 `read`，使用 secrets 管理器或环境变量注入密码。
- 若要使用真实 TLS 证书，请在 `04-deploy-nextcloud.sh` 中替换自签名证书生成步骤，或在 `ssl` 目录放置你的证书与私钥。

**贡献**
- 欢迎提交 issue 或 PR。修改脚本前请在非生产环境测试。

**许可**
- 请参阅仓库根目录的 `LICENSE` 文件。

**修改与贡献**
- 修改脚本前请先在非生产环境测试，尽量保持幂等性和清晰的输出提示。
- 欢迎提交 issues 或 PR，描述您在使用中遇到的问题与改进建议。

**版权**
- 仓库遵循 `LICENSE` 文件中的许可。

**联系/作者**
- 作者: 仓库所有者（见仓库信息）。
