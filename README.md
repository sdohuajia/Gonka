# Gonka 节点部署操作文档

## 系统要求
- Ubuntu 系统
- Root 权限或 sudo 权限

## 快速开始

### 1. 运行脚本
```bash
bash docker.sh
```

### 2. 按顺序执行以下命令

#### 命令1：部署环境
- 自动安装 Docker 和 Docker Compose
- 配置 GPU 支持（如需要）
- 安装 HuggingFace CLI
- 下载部署文件
- 安装 inferenced 二进制文件

**注意**：首次运行需要较长时间，请耐心等待。

#### 命令2：创建钱包
- 创建 gonka 账户密钥
- **重要**：请妥善保存助记词，这是恢复账户的唯一方式

#### 命令3：配置环境变量
需要配置以下信息：
- 节点名称（可选，默认：node）
- 服务器 ML 操作密码（必填）
- API 端口（默认：8000）
- 服务器公共 IP（必填）
- PUBLIC_URL 端口（必填）
- P2P_EXTERNAL_ADDRESS 端口（必填）
- 账户公钥（从命令2获取）

脚本会自动：
- 修改 `SEED_API_URL`、`SEED_NODE_RPC_URL`、`SEED_NODE_P2P_URL` 为 node1
- 修改 `RPC_SERVER_URL_2` 为 node3
- 选择模型配置（Qwen 2.5-7B 或 QwQ-32）
- 下载模型权重
- 拉取 Docker 镜像
- 启动初始服务（tmkms, node）

#### 命令4：创建 ML 操作密钥
- 在 API 容器中创建 ML 操作密钥
- 注册主机到网络
- 授权权限（需要热钱包地址）

**注意**：每台服务器只需执行一次，重启后保持有效。

#### 命令5：启动全节点
- 自动修改 `docker-compose.yml` 中的 `BEACON_STATE_URL` 为 `https://beaconstate.info/`
- 启动所有 Docker 服务

#### 命令6：验证节点状态
- 输入钱包地址
- 获取验证 URL
- 在浏览器中打开验证节点状态

## 常用命令

### 查看服务状态
```bash
cd /root/gonka/deploy/join
docker compose ps
```

### 查看服务日志
```bash
docker compose logs -f
```

### 停止服务
```bash
docker compose down
```

### 重启服务
```bash
docker compose restart
```

## 重要提示

1. **安全保存**：命令2生成的助记词必须安全保存，建议写在纸上或存储在离线设备中
2. **顺序执行**：请按照命令1-6的顺序执行，不要跳过步骤
3. **网络要求**：确保服务器有稳定的网络连接
4. **配置文件位置**：`/root/gonka/deploy/join/config.env`

## 故障排查

- **Docker 未安装**：执行命令1
- **配置文件不存在**：执行命令1和命令3
- **服务启动失败**：检查配置文件是否正确，查看日志：`docker compose logs`
- **节点状态验证失败**：确认服务已启动（命令5），检查网络连接

## 联系信息

- 推特：@ferdie_jhovie
- 本脚本免费开源，请勿相信收费脚本

