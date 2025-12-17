#!/bin/bash

# Docker 一键安装脚本 (Ubuntu)
# 设置颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 检查是否为 root 用户并设置命令前缀
SUDO_CMD=""
check_root() {
    if [ "$EUID" -eq 0 ]; then
        echo -e "${YELLOW}[警告] 检测到使用 root 用户运行${NC}"
        echo -e "${YELLOW}[提示] 建议使用普通用户运行，脚本会在需要时使用 sudo${NC}"
        echo -e "${YELLOW}[提示] 继续使用 root 用户运行...${NC}"
        SUDO_CMD=""  # root 用户不需要 sudo
        echo ""
    else
        # 检查 sudo 权限
        if ! sudo -n true 2>/dev/null; then
            echo -e "${YELLOW}[提示] 此脚本需要 sudo 权限，可能需要输入密码${NC}"
            echo ""
        fi
        SUDO_CMD="sudo"  # 普通用户需要使用 sudo
    fi
}

# 检查系统是否为 Ubuntu
check_ubuntu() {
    if [ ! -f /etc/os-release ]; then
        echo -e "${RED}[错误] 无法检测系统类型${NC}"
        exit 1
    fi
    
    . /etc/os-release
    
    if [ "$ID" != "ubuntu" ]; then
        echo -e "${RED}[错误] 此脚本仅支持 Ubuntu 系统${NC}"
        echo -e "${YELLOW}[信息] 检测到的系统: $ID${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}[信息] 检测到 Ubuntu 系统: $VERSION${NC}"
    echo ""
}

# 检查 Docker 是否已安装
check_docker_installed() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   检查 Docker 安装状态${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    # 检查 docker 命令是否存在
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}[信息] Docker 未安装，将继续安装流程${NC}"
        echo ""
        return 1
    fi
    
    # Docker 已安装，获取版本信息
    DOCKER_VERSION=$(docker --version 2>/dev/null)
    echo -e "${GREEN}[信息] Docker 已安装: $DOCKER_VERSION${NC}"
    echo ""
    
    # 检查 Docker Compose
    if docker compose version &> /dev/null; then
        COMPOSE_VERSION=$(docker compose version 2>/dev/null | head -n1)
        echo -e "${GREEN}[信息] Docker Compose 已安装: $COMPOSE_VERSION${NC}"
    else
        echo -e "${YELLOW}[信息] Docker Compose 未检测到${NC}"
    fi
    echo ""
    
    # 检查 Docker 服务状态
    if $SUDO_CMD systemctl is-active --quiet docker 2>/dev/null; then
        echo -e "${GREEN}[信息] Docker 服务正在运行${NC}"
    else
        echo -e "${YELLOW}[信息] Docker 服务未运行，正在启动...${NC}"
        if $SUDO_CMD systemctl start docker 2>/dev/null; then
            echo -e "${GREEN}✓ Docker 服务启动成功${NC}"
        else
            echo -e "${RED}[错误] Docker 服务启动失败${NC}"
        fi
    fi
    
    # 设置开机自启
    if $SUDO_CMD systemctl is-enabled --quiet docker 2>/dev/null; then
        echo -e "${GREEN}[信息] Docker 服务已设置为开机自启${NC}"
    else
        echo -e "${YELLOW}[信息] 正在设置 Docker 服务开机自启...${NC}"
        $SUDO_CMD systemctl enable docker 2>/dev/null
        echo -e "${GREEN}✓ Docker 服务已设置为开机自启${NC}"
    fi
    echo ""
    
    # 检查当前用户是否在 docker 组中（root 用户跳过此检查）
    if [ "$EUID" -eq 0 ]; then
        echo -e "${GREEN}[信息] root 用户无需添加到 docker 组${NC}"
    elif groups | grep -q docker; then
        echo -e "${GREEN}[信息] 当前用户已在 docker 组中${NC}"
    else
        echo -e "${YELLOW}[提示] 当前用户不在 docker 组中${NC}"
        read -p "是否将当前用户添加到 docker 组？(y/n): " add_user
        if [[ "$add_user" =~ ^[Yy]$ ]]; then
            if $SUDO_CMD usermod -aG docker $USER 2>/dev/null; then
                echo -e "${GREEN}✓ 用户已添加到 docker 组${NC}"
                echo -e "${YELLOW}[提示] 需要重新登录或运行 'newgrp docker' 才能生效${NC}"
            else
                echo -e "${RED}[错误] 添加用户到 docker 组失败${NC}"
            fi
        fi
    fi
    echo ""
    
    # 验证 Docker 是否正常工作
    echo -e "${GREEN}[验证] 正在验证 Docker 是否正常工作...${NC}"
    if $SUDO_CMD docker info &> /dev/null; then
        echo -e "${GREEN}✓ Docker 运行正常${NC}"
    else
        echo -e "${YELLOW}[警告] Docker 可能存在问题，但已检测到安装${NC}"
    fi
    echo ""
    
    # Docker 已安装且正常，继续执行验证步骤
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}   Docker 已安装，跳过安装步骤${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${CYAN}Docker 状态信息：${NC}"
    echo ""
    echo -e "${YELLOW}Docker 版本：${NC}${GREEN}$DOCKER_VERSION${NC}"
    if command -v docker &> /dev/null && $SUDO_CMD docker info &> /dev/null; then
        echo -e "${YELLOW}Docker 服务：${NC}${GREEN}运行中${NC}"
    fi
    echo ""
    
    # 返回 0 表示 Docker 已安装，继续执行验证步骤
    return 0
}

# 卸载旧版本的 Docker
remove_old_docker() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   卸载旧版本 Docker${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    echo -e "${GREEN}[步骤] 正在卸载旧版本的 Docker...${NC}"
    $SUDO_CMD apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    echo -e "${GREEN}✓ 旧版本清理完成${NC}"
    echo ""
}

# 安装依赖包
install_dependencies() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   安装依赖包${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    echo -e "${GREEN}[步骤] 正在更新软件包列表...${NC}"
    if $SUDO_CMD apt-get update; then
        echo -e "${GREEN}✓ 软件包列表更新成功${NC}"
    else
        echo -e "${RED}[错误] 软件包列表更新失败${NC}"
        exit 1
    fi
    echo ""
    
    echo -e "${GREEN}[步骤] 正在安装必要的依赖包...${NC}"
    if $SUDO_CMD apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release; then
        echo -e "${GREEN}✓ 依赖包安装成功${NC}"
    else
        echo -e "${RED}[错误] 依赖包安装失败${NC}"
        exit 1
    fi
    echo ""
}

# 添加 Docker 官方 GPG 密钥
add_docker_gpg_key() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   添加 Docker 官方 GPG 密钥${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    echo -e "${GREEN}[步骤] 正在创建密钥目录...${NC}"
    $SUDO_CMD mkdir -p /etc/apt/keyrings
    echo -e "${GREEN}✓ 目录创建成功${NC}"
    echo ""
    
    echo -e "${GREEN}[步骤] 正在下载并添加 Docker GPG 密钥...${NC}"
    if curl -fsSL https://download.docker.com/linux/ubuntu/gpg | $SUDO_CMD gpg --dearmor -o /etc/apt/keyrings/docker.gpg; then
        echo -e "${GREEN}✓ GPG 密钥添加成功${NC}"
    else
        echo -e "${RED}[错误] GPG 密钥添加失败，请检查网络连接${NC}"
        exit 1
    fi
    echo ""
    
    # 设置正确的权限
    $SUDO_CMD chmod a+r /etc/apt/keyrings/docker.gpg
    echo -e "${GREEN}✓ 密钥权限设置完成${NC}"
    echo ""
}

# 添加 Docker 仓库
add_docker_repository() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   添加 Docker 官方仓库${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    # 获取系统架构
    ARCH=$(dpkg --print-architecture)
    CODENAME=$(lsb_release -cs)
    
    echo -e "${GREEN}[信息] 系统架构: $ARCH${NC}"
    echo -e "${GREEN}[信息] Ubuntu 代号: $CODENAME${NC}"
    echo ""
    
    echo -e "${GREEN}[步骤] 正在添加 Docker 仓库...${NC}"
    if echo \
        "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $CODENAME stable" | $SUDO_CMD tee /etc/apt/sources.list.d/docker.list > /dev/null; then
        echo -e "${GREEN}✓ Docker 仓库添加成功${NC}"
    else
        echo -e "${RED}[错误] Docker 仓库添加失败${NC}"
        exit 1
    fi
    echo ""
    
    echo -e "${GREEN}[步骤] 正在更新软件包列表...${NC}"
    if $SUDO_CMD apt-get update; then
        echo -e "${GREEN}✓ 软件包列表更新成功${NC}"
    else
        echo -e "${RED}[错误] 软件包列表更新失败${NC}"
        exit 1
    fi
    echo ""
}

# 安装 Docker
install_docker() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   安装 Docker${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    echo -e "${GREEN}[步骤] 正在安装 Docker Engine、CLI、Containerd 和 Docker Compose...${NC}"
    echo -e "${YELLOW}[提示] 这可能需要几分钟时间，请耐心等待...${NC}"
    echo ""
    
    if $SUDO_CMD apt-get install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin; then
        echo ""
        echo -e "${GREEN}✓ Docker 安装成功${NC}"
    else
        echo ""
        echo -e "${RED}[错误] Docker 安装失败${NC}"
        exit 1
    fi
    echo ""
}

# 配置 Docker 服务
configure_docker_service() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   配置 Docker 服务${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    echo -e "${GREEN}[步骤] 正在启动 Docker 服务...${NC}"
    if $SUDO_CMD systemctl start docker; then
        echo -e "${GREEN}✓ Docker 服务启动成功${NC}"
    else
        echo -e "${RED}[错误] Docker 服务启动失败${NC}"
        exit 1
    fi
    echo ""
    
    echo -e "${GREEN}[步骤] 正在设置 Docker 服务开机自启...${NC}"
    if $SUDO_CMD systemctl enable docker; then
        echo -e "${GREEN}✓ Docker 服务已设置为开机自启${NC}"
    else
        echo -e "${YELLOW}[警告] Docker 服务开机自启设置失败${NC}"
    fi
    echo ""
    
    # 检查服务状态
    if $SUDO_CMD systemctl is-active --quiet docker; then
        echo -e "${GREEN}✓ Docker 服务运行正常${NC}"
    else
        echo -e "${RED}[错误] Docker 服务未正常运行${NC}"
        exit 1
    fi
    echo ""
}

# 配置用户权限
configure_user_permissions() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   配置用户权限${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    # 检查当前用户是否已在 docker 组中
    if groups | grep -q docker; then
        echo -e "${GREEN}[信息] 当前用户已在 docker 组中${NC}"
    else
        echo -e "${GREEN}[步骤] 正在将当前用户添加到 docker 组...${NC}"
        if $SUDO_CMD usermod -aG docker $USER; then
            echo -e "${GREEN}✓ 用户已添加到 docker 组${NC}"
            echo -e "${YELLOW}[提示] 需要重新登录或运行 'newgrp docker' 才能不使用 sudo 运行 Docker${NC}"
        else
            echo -e "${RED}[错误] 添加用户到 docker 组失败${NC}"
        fi
    fi
    echo ""
}

# 验证安装
verify_installation() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   验证 Docker 安装${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    # 检查 docker 命令
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version 2>/dev/null)
        echo -e "${GREEN}✓ Docker 命令可用: $DOCKER_VERSION${NC}"
    else
        echo -e "${RED}[错误] Docker 命令不可用${NC}"
        exit 1
    fi
    echo ""
    
    # 检查 docker compose 命令
    if docker compose version &> /dev/null; then
        COMPOSE_VERSION=$(docker compose version 2>/dev/null)
        echo -e "${GREEN}✓ Docker Compose 可用: $COMPOSE_VERSION${NC}"
    else
        echo -e "${YELLOW}[警告] Docker Compose 不可用${NC}"
    fi
    echo ""
    
    # 运行测试容器
    echo -e "${GREEN}[步骤] 正在运行测试容器验证安装...${NC}"
    if $SUDO_CMD docker run --rm hello-world &> /dev/null; then
        echo -e "${GREEN}✓ Docker 测试容器运行成功${NC}"
        echo ""
        $SUDO_CMD docker run --rm hello-world
    else
        echo -e "${YELLOW}[警告] Docker 测试容器运行失败，但 Docker 可能已正确安装${NC}"
    fi
    echo ""
}

# 验证 GPU 支持
verify_gpu_support() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   验证 GPU 支持${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    # 检查 nvidia-smi 是否可用
    if ! command -v nvidia-smi &> /dev/null; then
        echo -e "${YELLOW}[信息] 未检测到 nvidia-smi 命令${NC}"
        echo -e "${YELLOW}[提示] 如果系统有 NVIDIA GPU，请先安装 NVIDIA 驱动程序${NC}"
        echo ""
        return 1
    fi
    
    echo -e "${GREEN}[信息] 检测到 NVIDIA 驱动${NC}"
    echo ""
    
    # 检查 nvidia-container-toolkit 是否安装
    if ! dpkg -l | grep -q nvidia-container-toolkit; then
        echo -e "${YELLOW}[信息] 未检测到 nvidia-container-toolkit${NC}"
        echo -e "${YELLOW}[提示] 需要安装 nvidia-container-toolkit 才能使用 GPU 支持${NC}"
        read -p "是否现在安装 nvidia-container-toolkit？(y/n): " install_nvidia_toolkit
        if [[ "$install_nvidia_toolkit" =~ ^[Yy]$ ]]; then
            install_nvidia_container_toolkit
        else
            echo -e "${YELLOW}[跳过] 跳过 GPU 支持验证${NC}"
            echo ""
            return 1
        fi
    else
        echo -e "${GREEN}[信息] nvidia-container-toolkit 已安装${NC}"
    fi
    echo ""
    
    # 检查 Docker 是否支持 --gpus 参数
    echo -e "${GREEN}[验证] 正在测试 Docker GPU 支持...${NC}"
    
    # 使用 sudo 或直接运行，取决于用户是否在 docker 组中或是否为 root
    DOCKER_CMD="docker"
    if [ "$EUID" -ne 0 ] && ! groups | grep -q docker; then
        DOCKER_CMD="sudo docker"
    fi
    
    # 检测 Ubuntu 版本并选择合适的镜像
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        UBUNTU_VERSION=$(echo "$VERSION_ID" | cut -d. -f1,2)
    else
        UBUNTU_VERSION="20.04"
    fi
    
    # 定义多个可用的镜像标签（按优先级排序）
    CUDA_IMAGES=(
        "nvidia/cuda:11.8.0-base-ubuntu${UBUNTU_VERSION}"
        "nvidia/cuda:11.8-base-ubuntu${UBUNTU_VERSION}"
        "nvidia/cuda:11.8.0-base-ubuntu20.04"
        "nvidia/cuda:11.8-base-ubuntu20.04"
        "nvidia/cuda:12.0.0-base-ubuntu${UBUNTU_VERSION}"
        "nvidia/cuda:12.0-base-ubuntu${UBUNTU_VERSION}"
        "nvidia/cuda:latest"
    )
    
    SELECTED_IMAGE=""
    
    # 尝试找到可用的镜像
    echo -e "${GREEN}[步骤] 正在查找可用的 CUDA 镜像...${NC}"
    for IMAGE in "${CUDA_IMAGES[@]}"; do
        echo -e "${YELLOW}   尝试镜像: $IMAGE${NC}"
        # 先尝试拉取镜像（如果不存在）
        if $DOCKER_CMD pull "$IMAGE" &> /dev/null; then
            SELECTED_IMAGE="$IMAGE"
            echo -e "${GREEN}   ✓ 镜像可用: $IMAGE${NC}"
            break
        fi
    done
    
    if [ -z "$SELECTED_IMAGE" ]; then
        echo -e "${YELLOW}[警告] 无法找到可用的 CUDA 镜像，尝试使用通用镜像...${NC}"
        # 尝试使用最新的基础镜像
        if $DOCKER_CMD pull nvidia/cuda:base-ubuntu20.04 &> /dev/null; then
            SELECTED_IMAGE="nvidia/cuda:base-ubuntu20.04"
        elif $DOCKER_CMD pull nvidia/cuda:base &> /dev/null; then
            SELECTED_IMAGE="nvidia/cuda:base"
        else
            echo -e "${RED}[错误] 无法拉取任何 CUDA 镜像${NC}"
            echo -e "${YELLOW}[提示] 请检查网络连接或手动拉取镜像${NC}"
            echo ""
            return 1
        fi
    fi
    echo ""
    
    # 测试 GPU 支持
    echo -e "${GREEN}[测试] 正在测试 GPU 支持（使用镜像: $SELECTED_IMAGE）...${NC}"
    if $DOCKER_CMD run --rm --gpus all "$SELECTED_IMAGE" nvidia-smi &> /dev/null; then
        echo -e "${GREEN}✓ Docker GPU 支持验证成功！${NC}"
        echo ""
        echo -e "${CYAN}GPU 信息：${NC}"
        $DOCKER_CMD run --rm --gpus all "$SELECTED_IMAGE" nvidia-smi
        echo ""
        return 0
    else
        echo -e "${YELLOW}[警告] Docker GPU 支持验证失败${NC}"
        echo -e "${YELLOW}[提示] 可能的原因：${NC}"
        echo -e "${YELLOW}   1. Docker 服务需要重启${NC}"
        echo -e "${YELLOW}   2. nvidia-container-toolkit 配置不正确${NC}"
        echo -e "${YELLOW}   3. NVIDIA 驱动未正确安装${NC}"
        echo -e "${YELLOW}   4. 可以尝试手动运行: $DOCKER_CMD run --rm --gpus all $SELECTED_IMAGE nvidia-smi${NC}"
        echo ""
        return 1
    fi
}

# 安装 NVIDIA Container Toolkit
install_nvidia_container_toolkit() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   安装 NVIDIA Container Toolkit${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    # 添加 GPG key
    echo -e "${GREEN}[步骤 1/4] 添加 NVIDIA Container Toolkit GPG key...${NC}"
    if curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | $SUDO_CMD gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg 2>/dev/null; then
        echo -e "${GREEN}✓ GPG key 添加成功${NC}"
    else
        echo -e "${RED}[错误] GPG key 添加失败${NC}"
        return 1
    fi
    echo ""
    
    # 添加仓库
    echo -e "${GREEN}[步骤 2/4] 添加 NVIDIA Container Toolkit 仓库...${NC}"
    if curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
       sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
       $SUDO_CMD tee /etc/apt/sources.list.d/nvidia-container-toolkit.list > /dev/null; then
        echo -e "${GREEN}✓ 仓库添加成功${NC}"
    else
        echo -e "${RED}[错误] 仓库添加失败${NC}"
        return 1
    fi
    echo ""
    
    # 更新并安装
    echo -e "${GREEN}[步骤 3/4] 更新软件包列表并安装 nvidia-container-toolkit...${NC}"
    if $SUDO_CMD apt-get update && $SUDO_CMD apt-get install -y nvidia-container-toolkit; then
        echo -e "${GREEN}✓ nvidia-container-toolkit 安装完成${NC}"
    else
        echo -e "${RED}[错误] nvidia-container-toolkit 安装失败${NC}"
        return 1
    fi
    echo ""
    
    # 配置 Docker runtime
    echo -e "${GREEN}[步骤 4/4] 配置 Docker GPU runtime...${NC}"
    if $SUDO_CMD nvidia-ctk runtime configure --runtime=docker; then
        echo -e "${GREEN}✓ Docker GPU runtime 配置成功${NC}"
    else
        echo -e "${RED}[错误] Docker GPU runtime 配置失败${NC}"
        return 1
    fi
    echo ""
    
    # 重启 Docker
    echo -e "${GREEN}[重启] 正在重启 Docker 服务...${NC}"
    if $SUDO_CMD systemctl restart docker; then
        echo -e "${GREEN}✓ Docker 服务已重启${NC}"
        echo ""
        sleep 2
    else
        echo -e "${RED}[错误] Docker 服务重启失败${NC}"
        return 1
    fi
}

# 安装和验证 HuggingFace CLI
install_and_verify_huggingface() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   安装 HuggingFace CLI${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    # 检查 Python 是否安装
    if ! command -v python3 &> /dev/null && ! command -v python &> /dev/null; then
        echo -e "${YELLOW}[信息] 未检测到 Python，正在安装...${NC}"
        if $SUDO_CMD apt-get update && $SUDO_CMD apt-get install -y python3 python3-pip; then
            echo -e "${GREEN}✓ Python 安装完成${NC}"
        else
            echo -e "${RED}[错误] Python 安装失败${NC}"
            echo -e "${YELLOW}[跳过] 跳过 HuggingFace CLI 安装${NC}"
            echo ""
            return 1
        fi
        echo ""
    fi
    
    # 确定 pip 命令
    PIP_CMD="pip3"
    if command -v pip &> /dev/null; then
        PIP_CMD="pip"
    elif command -v pip3 &> /dev/null; then
        PIP_CMD="pip3"
    else
        echo -e "${YELLOW}[信息] 未检测到 pip，正在安装...${NC}"
        if $SUDO_CMD apt-get install -y python3-pip; then
            PIP_CMD="pip3"
            echo -e "${GREEN}✓ pip 安装完成${NC}"
        else
            echo -e "${RED}[错误] pip 安装失败${NC}"
            echo -e "${YELLOW}[跳过] 跳过 HuggingFace CLI 安装${NC}"
            echo ""
            return 1
        fi
    fi
    echo ""
    
    # 检查 huggingface_hub 是否已安装
    if $PIP_CMD show huggingface_hub &> /dev/null; then
        HF_VERSION=$($PIP_CMD show huggingface_hub 2>/dev/null | grep "^Version:" | awk '{print $2}')
        echo -e "${GREEN}[信息] HuggingFace Hub 已安装: 版本 $HF_VERSION${NC}"
        echo ""
    else
        echo -e "${GREEN}[步骤] 正在安装 huggingface_hub...${NC}"
        if $PIP_CMD install huggingface_hub; then
            echo -e "${GREEN}✓ HuggingFace Hub 安装完成${NC}"
        else
            echo -e "${RED}[错误] HuggingFace Hub 安装失败${NC}"
            echo -e "${YELLOW}[提示] 可以稍后手动运行: $PIP_CMD install huggingface_hub${NC}"
            echo ""
            return 1
        fi
        echo ""
    fi
    
    # 验证安装
    echo -e "${GREEN}[验证] 正在验证 HuggingFace CLI...${NC}"
    if python3 -c "import huggingface_hub; print('HuggingFace Hub version:', huggingface_hub.__version__)" 2>/dev/null; then
        HF_VERSION=$(python3 -c "import huggingface_hub; print(huggingface_hub.__version__)" 2>/dev/null)
        echo -e "${GREEN}✓ HuggingFace Hub 验证成功: 版本 $HF_VERSION${NC}"
        echo ""
        
        # 检查 huggingface-cli 命令（多种方式）
        HF_CLI_AVAILABLE=false
        HF_CLI_CMD=""
        
        # 方式1: 检查 PATH 中的 huggingface-cli
        if command -v huggingface-cli &> /dev/null; then
            HF_CLI_CMD="huggingface-cli"
            HF_CLI_AVAILABLE=true
        # 方式2: 尝试使用 Python 模块方式
        elif python3 -m huggingface_hub.cli --help &> /dev/null; then
            HF_CLI_CMD="python3 -m huggingface_hub.cli"
            HF_CLI_AVAILABLE=true
        # 方式3: 查找用户本地 bin 目录中的命令
        elif [ -f "$HOME/.local/bin/huggingface-cli" ]; then
            HF_CLI_CMD="$HOME/.local/bin/huggingface-cli"
            HF_CLI_AVAILABLE=true
        # 方式4: 查找 Python site-packages 中的脚本
        else
            HF_CLI_PATH=$(python3 -c "import site; import os; print(os.path.join(site.getuserbase(), 'bin', 'huggingface-cli'))" 2>/dev/null)
            if [ -f "$HF_CLI_PATH" ]; then
                HF_CLI_CMD="$HF_CLI_PATH"
                HF_CLI_AVAILABLE=true
            fi
        fi
        
        if [ "$HF_CLI_AVAILABLE" = true ]; then
            echo -e "${GREEN}✓ HuggingFace CLI 命令可用${NC}"
            if [ "$HF_CLI_CMD" != "huggingface-cli" ]; then
                echo -e "${YELLOW}[提示] 使用命令: $HF_CLI_CMD${NC}"
                # 尝试创建符号链接到 /usr/local/bin（如果可能）
                if [ "$EUID" -eq 0 ] || sudo -n true 2>/dev/null; then
                    if [ -f "$HF_CLI_CMD" ] && [ ! -f "/usr/local/bin/huggingface-cli" ]; then
                        echo -e "${GREEN}[步骤] 正在创建系统级符号链接...${NC}"
                        $SUDO_CMD ln -sf "$HF_CLI_CMD" /usr/local/bin/huggingface-cli 2>/dev/null && \
                            echo -e "${GREEN}✓ 符号链接已创建，现在可以直接使用 'huggingface-cli' 命令${NC}" || \
                            echo -e "${YELLOW}[提示] 符号链接创建失败，请使用: $HF_CLI_CMD${NC}"
                    fi
                fi
            fi
            echo ""
        else
            echo -e "${YELLOW}[信息] HuggingFace CLI 命令未在 PATH 中，但库已安装${NC}"
            echo -e "${YELLOW}[提示] 可以使用以下方式调用：${NC}"
            echo -e "${YELLOW}   - Python 模块: python3 -m huggingface_hub.cli${NC}"
            echo -e "${YELLOW}   - Python 导入: python3 -c 'import huggingface_hub'${NC}"
            echo ""
            # 尝试安装 CLI 入口点
            echo -e "${GREEN}[步骤] 正在尝试安装 CLI 入口点...${NC}"
            if $PIP_CMD install --upgrade --force-reinstall huggingface_hub &> /dev/null; then
                if command -v huggingface-cli &> /dev/null; then
                    echo -e "${GREEN}✓ HuggingFace CLI 命令现在可用${NC}"
                else
                    echo -e "${YELLOW}[提示] 请使用: python3 -m huggingface_hub.cli${NC}"
                fi
            fi
            echo ""
        fi
        
        return 0
    else
        echo -e "${YELLOW}[警告] HuggingFace Hub 验证失败${NC}"
        echo -e "${YELLOW}[提示] 可以尝试重新安装: $PIP_CMD install --upgrade huggingface_hub${NC}"
        echo ""
        return 1
    fi
}

# 获取 huggingface-cli 命令（辅助函数）
get_huggingface_cli_cmd() {
    # 方式1: 检查 PATH 中的 huggingface-cli
    if command -v huggingface-cli &> /dev/null; then
        echo "huggingface-cli"
        return 0
    fi
    
    # 方式2: 查找用户本地 bin 目录中的命令
    if [ -f "$HOME/.local/bin/huggingface-cli" ]; then
        echo "$HOME/.local/bin/huggingface-cli"
        return 0
    fi
    
    # 方式3: 查找 Python site-packages 中的脚本
    HF_CLI_PATH=$(python3 -c "import site; import os; print(os.path.join(site.getuserbase(), 'bin', 'huggingface-cli'))" 2>/dev/null)
    if [ -n "$HF_CLI_PATH" ] && [ -f "$HF_CLI_PATH" ]; then
        echo "$HF_CLI_PATH"
        return 0
    fi
    
    # 如果都找不到，返回空（将使用 Python API 方式）
    return 1
}

# 下载部署文件
download_deployment_files() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   下载部署文件${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    # 保存当前工作目录
    ORIGINAL_DIR=$(pwd)
    
    # 检查 git 是否安装
    if ! command -v git &> /dev/null; then
        echo -e "${YELLOW}[信息] 未检测到 git，正在安装...${NC}"
        if $SUDO_CMD apt-get update && $SUDO_CMD apt-get install -y git; then
            echo -e "${GREEN}✓ git 安装完成${NC}"
        else
            echo -e "${RED}[错误] git 安装失败${NC}"
            echo -e "${YELLOW}[跳过] 跳过部署文件下载${NC}"
            echo ""
            return 1
        fi
        echo ""
    fi
    
    # 检查是否已经存在 gonka 目录
    if [ -d "gonka" ]; then
        echo -e "${YELLOW}[信息] 检测到 gonka 目录已存在${NC}"
        read -p "是否重新克隆仓库？(y/n): " reclone
        if [[ "$reclone" =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}[步骤] 正在删除旧目录...${NC}"
            rm -rf gonka
            echo -e "${GREEN}✓ 旧目录已删除${NC}"
            echo ""
        else
            echo -e "${GREEN}[信息] 使用现有目录${NC}"
            echo ""
        fi
    fi
    
    # 克隆仓库
    if [ ! -d "gonka" ]; then
        echo -e "${GREEN}[步骤] 正在克隆 gonka 仓库...${NC}"
        if git clone https://github.com/gonka-ai/gonka.git -b main; then
            echo -e "${GREEN}✓ 仓库克隆成功${NC}"
        else
            echo -e "${RED}[错误] 仓库克隆失败${NC}"
            echo -e "${YELLOW}[提示] 请检查网络连接或 GitHub 访问${NC}"
            echo ""
            return 1
        fi
        echo ""
    fi
    
    # 进入部署目录
    if [ -d "gonka/deploy/join" ]; then
        echo -e "${GREEN}[步骤] 正在进入部署目录...${NC}"
        cd gonka/deploy/join || {
            echo -e "${RED}[错误] 无法进入部署目录${NC}"
            cd "$ORIGINAL_DIR"
            return 1
        }
        echo -e "${GREEN}✓ 已进入部署目录: $(pwd)${NC}"
        echo ""
        
        # 复制配置文件模板
        if [ -f "config.env.template" ]; then
            if [ ! -f "config.env" ]; then
                echo -e "${GREEN}[步骤] 正在复制配置文件模板...${NC}"
                if cp config.env.template config.env; then
                    echo -e "${GREEN}✓ 配置文件已创建: $(pwd)/config.env${NC}"
                    echo -e "${YELLOW}[提示] 请编辑 config.env 文件进行配置${NC}"
                else
                    echo -e "${RED}[错误] 配置文件复制失败${NC}"
                    cd "$ORIGINAL_DIR"
                    return 1
                fi
            else
                echo -e "${GREEN}[信息] 配置文件 config.env 已存在${NC}"
                echo -e "${YELLOW}[提示] 如需重新配置，请删除现有 config.env 文件${NC}"
            fi
        else
            echo -e "${YELLOW}[警告] 未找到 config.env.template 文件${NC}"
        fi
        echo ""
        
        # 返回原目录
        cd "$ORIGINAL_DIR"
        
        return 0
    else
        echo -e "${YELLOW}[警告] 未找到部署目录 gonka/deploy/join${NC}"
        echo -e "${YELLOW}[提示] 仓库结构可能已更改${NC}"
        echo ""
        return 1
    fi
}

# 下载并安装 inferenced 二进制文件
install_inferenced() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   下载并安装 inferenced${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    # 检查必要的工具是否安装
    MISSING_TOOLS=()
    if ! command -v wget &> /dev/null; then MISSING_TOOLS+=("wget"); fi
    if ! command -v unzip &> /dev/null; then MISSING_TOOLS+=("unzip"); fi
    if ! command -v curl &> /dev/null; then MISSING_TOOLS+=("curl"); fi
    
    if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
        echo -e "${YELLOW}[信息] 未检测到以下工具: ${MISSING_TOOLS[*]}，正在安装...${NC}"
        if $SUDO_CMD apt-get update && $SUDO_CMD apt-get install -y "${MISSING_TOOLS[@]}"; then
            echo -e "${GREEN}✓ 工具安装完成${NC}"
        else
            echo -e "${RED}[错误] 工具安装失败${NC}"
            echo -e "${YELLOW}[跳过] 跳过 inferenced 安装${NC}"
            echo ""
            return 1
        fi
        echo ""
    fi
    
    # 保存当前工作目录
    ORIGINAL_DIR=$(pwd)
    
    # 确定解压目录（root 用户主目录下的 gonka 目录）
    if [ "$EUID" -eq 0 ]; then
        EXTRACT_DIR="/root/gonka"
    else
        EXTRACT_DIR="$HOME/gonka"
    fi
    
    # 确定安装目录（优先使用 /usr/local/bin，需要 root 权限）
    INSTALL_DIR="/usr/local/bin"
    BINARY_NAME="inferenced"
    ZIP_FILE="inferenced-linux-amd64.zip"
    
    # 获取最新版本的下载链接
    echo -e "${GREEN}[步骤] 正在获取最新版本信息...${NC}"
    LATEST_URL=$(curl -s https://api.github.com/repos/gonka-ai/gonka/releases/latest | grep "browser_download_url.*inferenced-linux-amd64.zip" | cut -d '"' -f 4)
    
    if [ -z "$LATEST_URL" ]; then
        # 如果 API 获取失败，使用 latest 标签
        DOWNLOAD_URL="https://github.com/gonka-ai/gonka/releases/latest/download/inferenced-linux-amd64.zip"
        echo -e "${YELLOW}[信息] 使用默认下载链接${NC}"
    else
        DOWNLOAD_URL="$LATEST_URL"
        echo -e "${GREEN}✓ 已获取最新版本下载链接${NC}"
    fi
    echo ""
    
    # 检查是否已安装
    if command -v "$BINARY_NAME" &> /dev/null; then
        INSTALLED_PATH=$(which "$BINARY_NAME")
        echo -e "${GREEN}[信息] inferenced 已安装: $INSTALLED_PATH${NC}"
        read -p "是否重新下载并安装？(y/n): " reinstall
        if [[ ! "$reinstall" =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}[信息] 跳过安装，使用现有版本${NC}"
            echo ""
            return 0
        fi
        echo ""
    fi
    
    # 创建解压目录
    echo -e "${GREEN}[步骤] 正在创建解压目录: $EXTRACT_DIR${NC}"
    if [ ! -d "$EXTRACT_DIR" ]; then
        mkdir -p "$EXTRACT_DIR"
        echo -e "${GREEN}✓ 目录已创建${NC}"
    else
        echo -e "${GREEN}✓ 目录已存在${NC}"
    fi
    echo ""
    
    # 切换到解压目录
    cd "$EXTRACT_DIR" || {
        echo -e "${RED}[错误] 无法进入解压目录: $EXTRACT_DIR${NC}"
        return 1
    }
    echo -e "${GREEN}✓ 已切换到解压目录: $(pwd)${NC}"
    echo ""
    
    # 下载 zip 文件
    echo -e "${GREEN}[步骤] 正在下载最新版本的 inferenced zip 文件...${NC}"
    if wget -q --show-progress "$DOWNLOAD_URL" -O "$ZIP_FILE"; then
        echo -e "${GREEN}✓ 下载成功: $EXTRACT_DIR/$ZIP_FILE${NC}"
    else
        echo -e "${RED}[错误] 下载失败${NC}"
        echo -e "${YELLOW}[提示] 请检查网络连接或 GitHub 访问${NC}"
        cd "$ORIGINAL_DIR"
        return 1
    fi
    echo ""
    
    # 解压 zip 文件
    echo -e "${GREEN}[步骤] 正在解压 zip 文件到 $EXTRACT_DIR...${NC}"
    if unzip -q -o "$ZIP_FILE" -d "$EXTRACT_DIR"; then
        echo -e "${GREEN}✓ 解压成功${NC}"
    else
        echo -e "${RED}[错误] 解压失败${NC}"
        cd "$ORIGINAL_DIR"
        return 1
    fi
    echo ""
    
    # 查找解压后的 inferenced 文件
    BINARY_FILE="$EXTRACT_DIR/$BINARY_NAME"
    if [ ! -f "$BINARY_FILE" ]; then
        # 可能在子目录中
        BINARY_FILE=$(find "$EXTRACT_DIR" -name "$BINARY_NAME" -type f | head -n1)
        if [ -z "$BINARY_FILE" ]; then
            echo -e "${RED}[错误] 未找到解压后的 inferenced 文件${NC}"
            cd "$ORIGINAL_DIR"
            return 1
        fi
    fi
    
    echo -e "${GREEN}[信息] 找到二进制文件: $BINARY_FILE${NC}"
    echo ""
    
    # 添加执行权限
    echo -e "${GREEN}[步骤] 正在添加执行权限...${NC}"
    if chmod +x "$BINARY_FILE"; then
        echo -e "${GREEN}✓ 执行权限已添加${NC}"
    else
        echo -e "${RED}[错误] 添加执行权限失败${NC}"
        cd "$ORIGINAL_DIR"
        return 1
    fi
    echo ""
    
    # 测试二进制文件
    echo -e "${GREEN}[测试] 正在测试二进制文件...${NC}"
    if "$BINARY_FILE" --help &> /dev/null; then
        echo -e "${GREEN}✓ 二进制文件测试成功${NC}"
    else
        echo -e "${YELLOW}[警告] 二进制文件测试失败，但将继续安装${NC}"
    fi
    echo ""
    
    # 安装到系统目录
    echo -e "${GREEN}[步骤] 正在安装到系统目录 ($INSTALL_DIR)...${NC}"
    if $SUDO_CMD cp "$BINARY_FILE" "$INSTALL_DIR/$BINARY_NAME"; then
        $SUDO_CMD chmod +x "$INSTALL_DIR/$BINARY_NAME"
        echo -e "${GREEN}✓ inferenced 已安装到 $INSTALL_DIR/$BINARY_NAME${NC}"
    else
        echo -e "${RED}[错误] 安装失败${NC}"
        cd "$ORIGINAL_DIR"
        return 1
    fi
    echo ""
    
    # 清理下载的 zip 文件
    echo -e "${GREEN}[清理] 正在清理下载的 zip 文件...${NC}"
    rm -f "$ZIP_FILE"
    echo -e "${GREEN}✓ 清理完成${NC}"
    echo ""
    
    # 验证安装
    echo -e "${GREEN}[验证] 正在验证安装...${NC}"
    if command -v "$BINARY_NAME" &> /dev/null; then
        INSTALLED_VERSION=$($BINARY_NAME --version 2>/dev/null || $BINARY_NAME --help 2>/dev/null | head -n1 || echo "已安装")
        echo -e "${GREEN}✓ inferenced 安装成功${NC}"
        echo -e "${GREEN}   位置: $(which $BINARY_NAME)${NC}"
        echo ""
        
        # 显示帮助信息
        echo -e "${CYAN}inferenced 使用帮助：${NC}"
        $BINARY_NAME --help 2>/dev/null | head -n10 || echo -e "${YELLOW}   运行 '$BINARY_NAME --help' 查看完整帮助${NC}"
        echo ""
    else
        echo -e "${YELLOW}[警告] inferenced 命令未在 PATH 中找到${NC}"
        echo -e "${YELLOW}[提示] 可能需要重新加载 shell 或检查 PATH 设置${NC}"
        echo ""
    fi
    
    # 返回原目录
    cd "$ORIGINAL_DIR"
    
    return 0
}

# 显示使用说明
show_usage_info() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}   Docker 安装完成！${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${CYAN}使用说明：${NC}"
    echo ""
    echo -e "${YELLOW}1. 如果当前用户已添加到 docker 组，需要：${NC}"
    echo -e "   ${GREEN}   - 重新登录系统，或${NC}"
    echo -e "   ${GREEN}   - 运行命令: newgrp docker${NC}"
    echo ""
    echo -e "${YELLOW}2. 验证安装（无需 sudo）：${NC}"
    echo -e "   ${GREEN}   docker --version${NC}"
    echo -e "   ${GREEN}   docker ps${NC}"
    echo ""
    echo -e "${YELLOW}3. 运行测试容器：${NC}"
    echo -e "   ${GREEN}   docker run hello-world${NC}"
    echo ""
    echo -e "${YELLOW}4. 查看 Docker 信息：${NC}"
    echo -e "   ${GREEN}   docker info${NC}"
    echo ""
    echo -e "${YELLOW}5. 测试 GPU 支持（如果已配置）：${NC}"
    echo -e "   ${GREEN}   docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu20.04 nvidia-smi${NC}"
    echo -e "   ${GREEN}   或使用: docker run --rm --gpus all nvidia/cuda:latest nvidia-smi${NC}"
    echo ""
    echo -e "${YELLOW}6. 使用 HuggingFace CLI：${NC}"
    echo -e "   ${GREEN}   huggingface-cli --help${NC}"
    echo -e "   ${GREEN}   python3 -c 'import huggingface_hub'${NC}"
    echo ""
    echo -e "${YELLOW}7. 部署文件位置：${NC}"
    if [ -d "gonka/deploy/join" ]; then
        echo -e "   ${GREEN}   部署目录: $(pwd)/gonka/deploy/join${NC}"
        if [ -f "gonka/deploy/join/config.env" ]; then
            echo -e "   ${GREEN}   配置文件: $(pwd)/gonka/deploy/join/config.env${NC}"
            echo -e "   ${YELLOW}   请编辑配置文件进行自定义设置${NC}"
        fi
    else
        echo -e "   ${YELLOW}   部署文件未下载或目录不存在${NC}"
    fi
    echo ""
    echo -e "${YELLOW}8. 使用 inferenced：${NC}"
    if command -v inferenced &> /dev/null; then
        INFERENCED_PATH=$(which inferenced)
        echo -e "   ${GREEN}   inferenced 已安装: $INFERENCED_PATH${NC}"
        echo -e "   ${GREEN}   运行: inferenced --help${NC}"
    else
        echo -e "   ${YELLOW}   inferenced 未安装或不在 PATH 中${NC}"
    fi
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo ""
}

# 命令1：部署环境
command1_deploy_environment() {
    clear
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   命令1：部署环境${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    # 执行检查步骤
    check_root
    check_ubuntu
    
    # 检查 Docker 是否已安装
    DOCKER_ALREADY_INSTALLED=false
    if check_docker_installed; then
        # Docker 已安装，设置标志
        DOCKER_ALREADY_INSTALLED=true
    fi
    
    # 如果 Docker 未安装，执行安装流程
    if [ "$DOCKER_ALREADY_INSTALLED" = false ]; then
        echo -e "${YELLOW}[信息] 开始安装 Docker...${NC}"
        echo ""
        
        # 执行安装步骤
        remove_old_docker
        install_dependencies
        add_docker_gpg_key
        add_docker_repository
        install_docker
        configure_docker_service
        configure_user_permissions
        verify_installation
    fi
    
    # Docker 安装完成或已存在，执行验证步骤
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   执行附加验证和安装${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    # 验证 GPU 支持
    verify_gpu_support
    
    # 安装和验证 HuggingFace CLI
    install_and_verify_huggingface
    
    # 下载部署文件
    download_deployment_files
    
    # 下载并安装 inferenced
    install_inferenced
    
    # 显示使用说明
    show_usage_info
    
    echo ""
    read -p "按 Enter 键返回主菜单..."
}

# 命令2：创建钱包
command2_create_wallet() {
    clear
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   命令2：创建钱包${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    # 保存当前工作目录
    ORIGINAL_DIR=$(pwd)
    
    # 确定 gonka 目录路径
    if [ "$EUID" -eq 0 ]; then
        GONKA_DIR="/root/gonka"
    else
        GONKA_DIR="$HOME/gonka"
    fi
    
    # 检查 gonka 目录是否存在
    if [ ! -d "$GONKA_DIR" ]; then
        echo -e "${RED}[错误] 未找到 gonka 目录: $GONKA_DIR${NC}"
        echo -e "${YELLOW}[提示] 请先执行命令1：部署环境${NC}"
        echo ""
        read -p "按 Enter 键返回主菜单..."
        return 1
    fi
    
    echo -e "${GREEN}[信息] 正在进入目录: $GONKA_DIR${NC}"
    cd "$GONKA_DIR" || {
        echo -e "${RED}[错误] 无法进入目录: $GONKA_DIR${NC}"
        cd "$ORIGINAL_DIR"
        read -p "按 Enter 键返回主菜单..."
        return 1
    }
    echo -e "${GREEN}✓ 已进入目录${NC}"
    echo ""
    
    # 检查 inferenced 是否可用
    if command -v inferenced &> /dev/null; then
        INFERENCED_CMD="inferenced"
    elif [ -f "./inferenced" ]; then
        INFERENCED_CMD="./inferenced"
    else
        echo -e "${RED}[错误] 未找到 inferenced 命令${NC}"
        echo -e "${YELLOW}[提示] 请先执行命令1：部署环境${NC}"
        echo ""
        cd "$ORIGINAL_DIR"
        read -p "按 Enter 键返回主菜单..."
        return 1
    fi
    
    # 显示重要提示
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}   极其重要：安全提示${NC}"
    echo -e "${RED}========================================${NC}"
    echo ""
    echo -e "${RED}将助记词记录下来并存储在安全的离线位置。${NC}"
    echo -e "${RED}这是恢复您账户密钥的唯一方法！${NC}"
    echo ""
    echo -e "${YELLOW}请确保：${NC}"
    echo -e "${YELLOW}  1. 将助记词写在纸上或存储在安全的离线设备中${NC}"
    echo -e "${YELLOW}  2. 不要将助记词存储在联网设备或云端${NC}"
    echo -e "${YELLOW}  3. 不要与他人分享您的助记词${NC}"
    echo ""
    echo -e "${RED}========================================${NC}"
    echo ""
    
    read -p "我已理解上述安全提示，按 Enter 键继续创建钱包..."
    echo ""
    
    # 执行创建钱包命令
    echo -e "${GREEN}[步骤] 正在创建钱包...${NC}"
    echo -e "${YELLOW}[提示] 请按照提示输入密码和确认密码${NC}"
    echo ""
    
    if $INFERENCED_CMD keys add gonka-account-key --keyring-backend file; then
        echo ""
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}   钱包创建成功！${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo ""
        echo -e "${CYAN}钱包信息：${NC}"
        echo -e "${GREEN}  密钥名称: gonka-account-key${NC}"
        echo -e "${GREEN}  密钥类型: file${NC}"
        echo ""
        echo -e "${RED}请确保已将助记词安全保存！${NC}"
        echo ""
    else
        echo ""
        echo -e "${RED}[错误] 钱包创建失败${NC}"
        echo -e "${YELLOW}[提示] 请检查错误信息并重试${NC}"
        echo ""
    fi
    
    # 返回原目录
    cd "$ORIGINAL_DIR"
    
    echo ""
    read -p "按 Enter 键返回主菜单..."
}

# 命令3：配置环境变量
command3_configure_env() {
    clear
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   命令3：配置环境变量${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    # 保存当前工作目录
    ORIGINAL_DIR=$(pwd)
    
    # 确定配置文件路径
    if [ "$EUID" -eq 0 ]; then
        CONFIG_DIR="/root/gonka/deploy/join"
    else
        CONFIG_DIR="$HOME/gonka/deploy/join"
    fi
    
    CONFIG_FILE="$CONFIG_DIR/config.env"
    
    # 检查配置文件目录是否存在
    if [ ! -d "$CONFIG_DIR" ]; then
        echo -e "${RED}[错误] 未找到配置目录: $CONFIG_DIR${NC}"
        echo -e "${YELLOW}[提示] 请先执行命令1：部署环境${NC}"
        echo ""
        read -p "按 Enter 键返回主菜单..."
        return 1
    fi
    
    # 检查配置文件模板是否存在
    TEMPLATE_FILE="$CONFIG_DIR/config.env.template"
    
    # 读取现有配置文件或模板
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "${GREEN}[信息] 检测到配置文件已存在，将更新用户配置项${NC}"
        CONFIG_TEMP=$(mktemp)
        cp "$CONFIG_FILE" "$CONFIG_TEMP"
    elif [ -f "$TEMPLATE_FILE" ]; then
        echo -e "${GREEN}[信息] 使用配置文件模板${NC}"
        CONFIG_TEMP=$(mktemp)
        cp "$TEMPLATE_FILE" "$CONFIG_TEMP"
    else
        echo -e "${YELLOW}[信息] 未找到配置文件模板，将创建新配置文件${NC}"
        CONFIG_TEMP=$(mktemp)
        # 创建默认模板内容
        cat > "$CONFIG_TEMP" << 'EOF'
export KEY_NAME=<FILLIN>
export KEYRING_PASSWORD=<FILLIN>
export API_PORT=8000
export API_SSL_PORT=8443
export PUBLIC_URL=http://<HOST>:<PORT>
export P2P_EXTERNAL_ADDRESS=tcp://<HOST>:<PORT>
export ACCOUNT_PUBKEY=<ACCOUNT_PUBKEY_FROM_STEP_ABOVE>
export NODE_CONFIG=./node-config.json
export HF_HOME=/mnt/shared
export SEED_API_URL=http://node2.gonka.ai:8000
export SEED_NODE_RPC_URL=http://node2.gonka.ai:26657
export SEED_NODE_P2P_URL=tcp://node2.gonka.ai:5000
export DAPI_API__POC_CALLBACK_URL=http://api:9100
export DAPI_CHAIN_NODE__URL=http://node:26657
export DAPI_CHAIN_NODE__P2P_URL=http://node:26656
export RPC_SERVER_URL_1=http://node1.gonka.ai:26657
export RPC_SERVER_URL_2=http://node2.gonka.ai:26657
export PORT=8080
export INFERENCE_PORT=5050
export KEYRING_BACKEND=file
EOF
    fi
    echo ""
    
    echo -e "${GREEN}[步骤] 开始配置环境变量...${NC}"
    echo ""
    
    # 1. 节点名称（可选，默认为node）
    echo -e "${CYAN}1. 节点名称 (KEY_NAME)${NC}"
    echo -e "${YELLOW}   可填可不填，不填默认为 node${NC}"
    read -p "请输入节点名称 [默认: node]: " KEY_NAME
    if [ -z "$KEY_NAME" ]; then
        KEY_NAME="node"
    fi
    echo -e "${GREEN}   ✓ 节点名称: $KEY_NAME${NC}"
    echo ""
    
    # 2. 服务器ML操作密码（必填）
    echo -e "${CYAN}2. 服务器ML操作密码 (KEYRING_PASSWORD)${NC}"
    echo -e "${YELLOW}   必填项${NC}"
    while [ -z "$KEYRING_PASSWORD" ]; do
        read -sp "请输入服务器ML操作密码: " KEYRING_PASSWORD
        echo ""
        if [ -z "$KEYRING_PASSWORD" ]; then
            echo -e "${RED}   [错误] 密码不能为空，请重新输入${NC}"
        fi
    done
    echo -e "${GREEN}   ✓ 密码已设置${NC}"
    echo ""
    
    # 3. API端口（默认8000，可更改）
    echo -e "${CYAN}3. API端口 (API_PORT)${NC}"
    echo -e "${YELLOW}   默认端口: 8000${NC}"
    read -p "请输入API端口 [默认: 8000]: " API_PORT
    if [ -z "$API_PORT" ]; then
        API_PORT="8000"
    fi
    # 验证端口是否为数字
    if ! [[ "$API_PORT" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}   [错误] 端口必须是数字，使用默认值 8000${NC}"
        API_PORT="8000"
    fi
    echo -e "${GREEN}   ✓ API端口: $API_PORT${NC}"
    echo ""
    
    # 4. 服务器公共IP（用于PUBLIC_URL和P2P_EXTERNAL_ADDRESS）
    echo -e "${CYAN}4. 服务器公共IP (HOST)${NC}"
    echo -e "${YELLOW}   用于 PUBLIC_URL 和 P2P_EXTERNAL_ADDRESS${NC}"
    while [ -z "$PUBLIC_HOST" ]; do
        read -p "请输入服务器公共IP: " PUBLIC_HOST
        if [ -z "$PUBLIC_HOST" ]; then
            echo -e "${RED}   [错误] IP地址不能为空，请重新输入${NC}"
        fi
    done
    echo -e "${GREEN}   ✓ 服务器公共IP: $PUBLIC_HOST${NC}"
    echo ""
    
    # 4.1. PUBLIC_URL 端口
    echo -e "${CYAN}4.1. PUBLIC_URL 端口${NC}"
    echo -e "${YELLOW}   用于 PUBLIC_URL${NC}"
    echo -e "${RED}   [必填] 必须填写，不能使用默认值${NC}"
    while [ -z "$PUBLIC_URL_PORT" ]; do
        read -p "请输入 PUBLIC_URL 端口: " PUBLIC_URL_PORT
        if [ -z "$PUBLIC_URL_PORT" ]; then
            echo -e "${RED}   [错误] 端口不能为空，请重新输入${NC}"
        elif ! [[ "$PUBLIC_URL_PORT" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}   [错误] 端口必须是数字，请重新输入${NC}"
            PUBLIC_URL_PORT=""
        fi
    done
    echo -e "${GREEN}   ✓ PUBLIC_URL 端口: $PUBLIC_URL_PORT${NC}"
    echo ""
    
    # 4.2. P2P_EXTERNAL_ADDRESS 端口
    echo -e "${CYAN}4.2. P2P_EXTERNAL_ADDRESS 端口${NC}"
    echo -e "${YELLOW}   用于 P2P_EXTERNAL_ADDRESS${NC}"
    echo -e "${RED}   [必填] 必须填写，不能使用默认值${NC}"
    while [ -z "$P2P_PORT" ]; do
        read -p "请输入 P2P_EXTERNAL_ADDRESS 端口: " P2P_PORT
        if [ -z "$P2P_PORT" ]; then
            echo -e "${RED}   [错误] 端口不能为空，请重新输入${NC}"
        elif ! [[ "$P2P_PORT" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}   [错误] 端口必须是数字，请重新输入${NC}"
            P2P_PORT=""
        fi
    done
    echo -e "${GREEN}   ✓ P2P_EXTERNAL_ADDRESS 端口: $P2P_PORT${NC}"
    echo ""
    
    # 5. ACCOUNT_PUBKEY（必填）
    echo -e "${CYAN}5. 账户公钥 (ACCOUNT_PUBKEY)${NC}"
    echo -e "${YELLOW}   必填项，从命令2创建钱包步骤中获取${NC}"
    while [ -z "$ACCOUNT_PUBKEY" ]; do
        read -p "请输入账户公钥 (ACCOUNT_PUBKEY): " ACCOUNT_PUBKEY
        if [ -z "$ACCOUNT_PUBKEY" ]; then
            echo -e "${RED}   [错误] 账户公钥不能为空，请重新输入${NC}"
        fi
    done
    echo -e "${GREEN}   ✓ 账户公钥已设置${NC}"
    echo ""
    
    # 更新配置文件
    echo -e "${GREEN}[步骤] 正在更新配置文件...${NC}"
    
    # 使用 awk 安全地替换配置项（避免特殊字符问题）
    awk -v key_name="$KEY_NAME" \
        -v keyring_password="$KEYRING_PASSWORD" \
        -v api_port="$API_PORT" \
        -v public_host="$PUBLIC_HOST" \
        -v public_url_port="$PUBLIC_URL_PORT" \
        -v p2p_port="$P2P_PORT" \
        -v account_pubkey="$ACCOUNT_PUBKEY" \
    'BEGIN {
        updated["KEY_NAME"] = 0
        updated["KEYRING_PASSWORD"] = 0
        updated["API_PORT"] = 0
        updated["PUBLIC_URL"] = 0
        updated["P2P_EXTERNAL_ADDRESS"] = 0
        updated["ACCOUNT_PUBKEY"] = 0
    }
    /^export KEY_NAME=/ {
        print "export KEY_NAME=" key_name
        updated["KEY_NAME"] = 1
        next
    }
    /^export KEYRING_PASSWORD=/ {
        print "export KEYRING_PASSWORD=" keyring_password
        updated["KEYRING_PASSWORD"] = 1
        next
    }
    /^export API_PORT=/ {
        print "export API_PORT=" api_port
        updated["API_PORT"] = 1
        next
    }
    /^export PUBLIC_URL=/ {
        print "export PUBLIC_URL=http://" public_host ":" public_url_port
        updated["PUBLIC_URL"] = 1
        next
    }
    /^export P2P_EXTERNAL_ADDRESS=/ {
        print "export P2P_EXTERNAL_ADDRESS=tcp://" public_host ":" p2p_port
        updated["P2P_EXTERNAL_ADDRESS"] = 1
        next
    }
    /^export ACCOUNT_PUBKEY=/ {
        print "export ACCOUNT_PUBKEY=" account_pubkey
        updated["ACCOUNT_PUBKEY"] = 1
        next
    }
    /^export SEED_API_URL=/ {
        if ($0 ~ /node2\.gonka\.ai:8000/) {
            print "export SEED_API_URL=http://node1.gonka.ai:8000"
        } else {
            print $0
        }
        updated["SEED_API_URL"] = 1
        next
    }
    /^export SEED_NODE_RPC_URL=/ {
        if ($0 ~ /node2\.gonka\.ai:26657/) {
            print "export SEED_NODE_RPC_URL=http://node1.gonka.ai:26657"
        } else {
            print $0
        }
        updated["SEED_NODE_RPC_URL"] = 1
        next
    }
    /^export SEED_NODE_P2P_URL=/ {
        if ($0 ~ /node2\.gonka\.ai:5000/) {
            print "export SEED_NODE_P2P_URL=tcp://node1.gonka.ai:5000"
        } else {
            print $0
        }
        updated["SEED_NODE_P2P_URL"] = 1
        next
    }
    /^export RPC_SERVER_URL_2=/ {
        if ($0 ~ /node2\.gonka\.ai:26657/) {
            print "export RPC_SERVER_URL_2=http://node3.gonka.ai:26657"
        } else {
            print $0
        }
        updated["RPC_SERVER_URL_2"] = 1
        next
    }
    { print }
    END {
        # 如果某些配置项不存在，在文件末尾添加
        if (!updated["KEY_NAME"]) {
            print "export KEY_NAME=" key_name
        }
        if (!updated["KEYRING_PASSWORD"]) {
            print "export KEYRING_PASSWORD=" keyring_password
        }
        if (!updated["API_PORT"]) {
            print "export API_PORT=" api_port
        }
        if (!updated["PUBLIC_URL"]) {
            print "export PUBLIC_URL=http://" public_host ":" public_url_port
        }
        if (!updated["P2P_EXTERNAL_ADDRESS"]) {
            print "export P2P_EXTERNAL_ADDRESS=tcp://" public_host ":" p2p_port
        }
        if (!updated["ACCOUNT_PUBKEY"]) {
            print "export ACCOUNT_PUBKEY=" account_pubkey
        }
    }' "$CONFIG_TEMP" > "$CONFIG_TEMP.new" && mv "$CONFIG_TEMP.new" "$CONFIG_TEMP"
    
    # 将更新后的配置写入文件
    if cp "$CONFIG_TEMP" "$CONFIG_FILE"; then
        rm -f "$CONFIG_TEMP"
        echo -e "${GREEN}✓ 配置文件已更新: $CONFIG_FILE${NC}"
        echo ""
        
        # 显示更新的配置内容（隐藏密码）
        echo -e "${CYAN}已更新的配置项：${NC}"
        echo -e "${GREEN}  KEY_NAME=$KEY_NAME${NC}"
        echo -e "${GREEN}  KEYRING_PASSWORD=***（已隐藏）${NC}"
        echo -e "${GREEN}  API_PORT=$API_PORT${NC}"
        echo -e "${GREEN}  PUBLIC_URL=http://$PUBLIC_HOST:$PUBLIC_URL_PORT${NC}"
        echo -e "${GREEN}  P2P_EXTERNAL_ADDRESS=tcp://$PUBLIC_HOST:$P2P_PORT${NC}"
        echo -e "${GREEN}  ACCOUNT_PUBKEY=$ACCOUNT_PUBKEY${NC}"
        echo ""
        echo -e "${CYAN}自动修改的配置项：${NC}"
        echo -e "${GREEN}  SEED_API_URL=http://node1.gonka.ai:8000${NC}"
        echo -e "${GREEN}  SEED_NODE_RPC_URL=http://node1.gonka.ai:26657${NC}"
        echo -e "${GREEN}  SEED_NODE_P2P_URL=tcp://node1.gonka.ai:5000${NC}"
        echo -e "${GREEN}  RPC_SERVER_URL_2=http://node3.gonka.ai:26657${NC}"
        echo ""
        echo -e "${YELLOW}[提示] 其他配置项已保留原值${NC}"
        echo ""
        
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}   环境变量配置完成！${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo ""
    else
        rm -f "$CONFIG_TEMP"
        echo -e "${RED}[错误] 配置文件写入失败${NC}"
        echo ""
        read -p "按 Enter 键返回主菜单..."
        return 1
    fi
    
    # 进入配置目录
    cd "$CONFIG_DIR" || {
        echo -e "${RED}[错误] 无法进入配置目录${NC}"
        cd "$ORIGINAL_DIR"
        read -p "按 Enter 键返回主菜单..."
        return 1
    }
    
    # 加载配置
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   加载配置${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "${GREEN}[步骤] 正在加载配置文件...${NC}"
    if source config.env; then
        echo -e "${GREEN}✓ 配置文件加载成功${NC}"
    else
        echo -e "${RED}[错误] 配置文件加载失败${NC}"
        cd "$ORIGINAL_DIR"
        read -p "按 Enter 键返回主菜单..."
        return 1
    fi
    echo ""
    
    # 选择模型配置
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   选择模型配置${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "${GREEN}请选择模型配置：${NC}"
    echo ""
    echo -e "${YELLOW}  1. Qwen 2.5-7B（默认）${NC}"
    echo -e "${YELLOW}  2. QwQ-32 (4 x 3090)${NC}"
    echo ""
    read -p "请输入选项 [1-2，默认: 1]: " model_choice
    if [ -z "$model_choice" ]; then
        model_choice="1"
    fi
    
    case $model_choice in
        1)
            echo -e "${GREEN}[信息] 已选择 Qwen 2.5-7B（默认配置）${NC}"
            MODEL_NAME="Qwen/Qwen2.5-7B-Instruct"
            echo ""
            ;;
        2)
            echo -e "${GREEN}[信息] 已选择 QwQ-32 (4 x 3090)${NC}"
            MODEL_NAME="Qwen/Qwen3-32B-FP8"
            
            # 检查源文件是否存在
            if [ -f "node-config-qwq-4x3090.json" ]; then
                echo -e "${GREEN}[步骤] 正在替换节点配置文件...${NC}"
                if cp node-config-qwq-4x3090.json node-config.json; then
                    echo -e "${GREEN}✓ 节点配置文件已替换${NC}"
                else
                    echo -e "${RED}[错误] 节点配置文件替换失败${NC}"
                    cd "$ORIGINAL_DIR"
                    read -p "按 Enter 键返回主菜单..."
                    return 1
                fi
            else
                echo -e "${YELLOW}[警告] 未找到 node-config-qwq-4x3090.json 文件${NC}"
                echo -e "${YELLOW}[提示] 将使用默认配置${NC}"
            fi
            echo ""
            ;;
        *)
            echo -e "${YELLOW}[信息] 无效选项，使用默认配置 Qwen 2.5-7B${NC}"
            MODEL_NAME="Qwen/Qwen2.5-7B-Instruct"
            echo ""
            ;;
    esac
    
    # 预下载模型权重
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   预下载模型权重${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    # 确保在配置目录中
    if [ "$(pwd)" != "$CONFIG_DIR" ]; then
        cd "$CONFIG_DIR" || {
            echo -e "${RED}[错误] 无法进入配置目录${NC}"
            cd "$ORIGINAL_DIR"
            read -p "按 Enter 键返回主菜单..."
            return 1
        }
    fi
    
    # 加载配置（参考步骤：source config.env）
    echo -e "${GREEN}[步骤] 正在加载配置文件...${NC}"
    if source config.env; then
        echo -e "${GREEN}✓ 配置文件加载成功${NC}"
    else
        echo -e "${RED}[错误] 配置文件加载失败${NC}"
        cd "$ORIGINAL_DIR"
        read -p "按 Enter 键返回主菜单..."
        return 1
    fi
    echo ""
    
    # 检查 HF_HOME 是否已设置
    if [ -z "$HF_HOME" ]; then
        echo -e "${YELLOW}[信息] HF_HOME 未设置，使用默认值 /mnt/shared${NC}"
        HF_HOME="/mnt/shared"
    fi
    
    # 创建缓存目录
    echo -e "${GREEN}[步骤] 正在创建缓存目录...${NC}"
    if $SUDO_CMD mkdir -p "$HF_HOME"; then
        echo -e "${GREEN}✓ 缓存目录已创建: $HF_HOME${NC}"
    else
        echo -e "${RED}[错误] 缓存目录创建失败${NC}"
        cd "$ORIGINAL_DIR"
        read -p "按 Enter 键返回主菜单..."
        return 1
    fi
    
    # 设置目录权限
    echo -e "${GREEN}[步骤] 正在设置目录权限...${NC}"
    if $SUDO_CMD chmod 777 "$HF_HOME"; then
        echo -e "${GREEN}✓ 目录权限已设置${NC}"
    else
        echo -e "${YELLOW}[警告] 目录权限设置失败，继续执行...${NC}"
    fi
    echo ""
    
    # 检查 huggingface-cli 是否可用，或使用 Python API
    HF_CLI_CMD=$(get_huggingface_cli_cmd)
    USE_PYTHON_API=false
    
    if [ -z "$HF_CLI_CMD" ]; then
        echo -e "${YELLOW}[警告] huggingface-cli 命令不可用${NC}"
        echo -e "${YELLOW}[步骤] 正在检查 Python API 方式...${NC}"
        
        # 检查 Python 和 huggingface_hub 是否可用
        if command -v python3 &> /dev/null && python3 -c "import huggingface_hub" &> /dev/null 2>&1; then
            USE_PYTHON_API=true
            echo -e "${GREEN}✓ 将使用 Python API 方式下载模型${NC}"
        else
            echo -e "${RED}[错误] 无法找到 HuggingFace CLI 或 Python 模块${NC}"
            echo -e "${YELLOW}[提示] 请先执行命令1：部署环境${NC}"
            echo -e "${YELLOW}[提示] 或者手动安装: pip3 install huggingface_hub${NC}"
            echo ""
            cd "$ORIGINAL_DIR"
            read -p "按 Enter 键返回主菜单..."
            return 1
        fi
        echo ""
    else
        echo -e "${GREEN}[信息] 使用 HuggingFace CLI 命令: $HF_CLI_CMD${NC}"
        echo ""
    fi
    
    # 下载模型
    echo -e "${GREEN}[步骤] 正在下载模型: $MODEL_NAME${NC}"
    echo -e "${YELLOW}[提示] 这可能需要较长时间，请耐心等待...${NC}"
    echo ""
    
    if [ "$USE_PYTHON_API" = true ]; then
        # 使用 Python API 下载模型
        if python3 << EOF
import sys
from huggingface_hub import snapshot_download

try:
    print(f"正在下载模型: $MODEL_NAME")
    print(f"缓存目录: $HF_HOME")
    snapshot_download(
        repo_id="$MODEL_NAME",
        cache_dir="$HF_HOME",
        local_files_only=False
    )
    print("模型下载完成！")
    sys.exit(0)
except Exception as e:
    print(f"下载失败: {e}", file=sys.stderr)
    sys.exit(1)
EOF
        then
            echo ""
            echo -e "${GREEN}========================================${NC}"
            echo -e "${GREEN}   模型下载完成！${NC}"
            echo -e "${GREEN}========================================${NC}"
            echo ""
            echo -e "${CYAN}模型信息：${NC}"
            echo -e "${GREEN}  模型名称: $MODEL_NAME${NC}"
            echo -e "${GREEN}  缓存目录: $HF_HOME${NC}"
            echo ""
        else
            echo ""
            echo -e "${RED}[错误] 模型下载失败${NC}"
            echo -e "${YELLOW}[提示] 请检查网络连接或稍后重试${NC}"
            echo ""
        fi
    else
        # 使用 CLI 命令下载模型
        if $HF_CLI_CMD download "$MODEL_NAME" --cache-dir "$HF_HOME"; then
            echo ""
            echo -e "${GREEN}========================================${NC}"
            echo -e "${GREEN}   模型下载完成！${NC}"
            echo -e "${GREEN}========================================${NC}"
            echo ""
            echo -e "${CYAN}模型信息：${NC}"
            echo -e "${GREEN}  模型名称: $MODEL_NAME${NC}"
            echo -e "${GREEN}  缓存目录: $HF_HOME${NC}"
            echo ""
        else
            echo ""
            echo -e "${RED}[错误] 模型下载失败${NC}"
            echo -e "${YELLOW}[提示] 请检查网络连接或稍后重试${NC}"
            echo ""
        fi
    fi
    
    # 拉取 Docker 镜像
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   拉取 Docker 镜像${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    # 确保在正确的目录中
    if [ "$(pwd)" != "$CONFIG_DIR" ]; then
        cd "$CONFIG_DIR" || {
            echo -e "${RED}[错误] 无法进入配置目录${NC}"
            cd "$ORIGINAL_DIR"
            read -p "按 Enter 键返回主菜单..."
            return 1
        }
    fi
    
    # 检查 docker 是否可用
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}[错误] Docker 未安装${NC}"
        echo -e "${YELLOW}[提示] 请先执行命令1：部署环境${NC}"
        echo ""
        cd "$ORIGINAL_DIR"
        read -p "按 Enter 键返回主菜单..."
        return 1
    fi
    
    # 检查 docker-compose.yml 文件是否存在
    if [ ! -f "docker-compose.yml" ]; then
        echo -e "${RED}[错误] 未找到 docker-compose.yml 文件${NC}"
        echo -e "${YELLOW}[提示] 请确保在正确的目录中: $CONFIG_DIR${NC}"
        echo ""
        cd "$ORIGINAL_DIR"
        read -p "按 Enter 键返回主菜单..."
        return 1
    fi
    
    # 检查 docker-compose.mlnode.yml 文件是否存在
    if [ ! -f "docker-compose.mlnode.yml" ]; then
        echo -e "${YELLOW}[警告] 未找到 docker-compose.mlnode.yml 文件${NC}"
        echo -e "${YELLOW}[提示] 将只使用 docker-compose.yml${NC}"
        COMPOSE_FILES="-f docker-compose.yml"
    else
        COMPOSE_FILES="-f docker-compose.yml -f docker-compose.mlnode.yml"
    fi
    
    echo -e "${GREEN}[步骤] 正在拉取 Docker 镜像...${NC}"
    echo -e "${YELLOW}[提示] 这可能需要较长时间，请耐心等待...${NC}"
    echo ""
    
    # 使用 sudo 或直接运行，取决于用户是否在 docker 组中或是否为 root
    DOCKER_COMPOSE_CMD="docker compose"
    if [ "$EUID" -ne 0 ] && ! groups | grep -q docker; then
        DOCKER_COMPOSE_CMD="sudo docker compose"
    fi
    
    if $DOCKER_COMPOSE_CMD $COMPOSE_FILES pull; then
        echo ""
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}   Docker 镜像拉取完成！${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo ""
    else
        echo ""
        echo -e "${RED}[错误] Docker 镜像拉取失败${NC}"
        echo -e "${YELLOW}[提示] 请检查网络连接或 Docker 配置${NC}"
        echo ""
        cd "$ORIGINAL_DIR"
        read -p "按 Enter 键返回主菜单..."
        return 1
    fi
    
    # 启动初始服务
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   启动初始服务${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    echo -e "${GREEN}[步骤] 正在启动初始服务 (tmkms, node)...${NC}"
    if source config.env && $DOCKER_COMPOSE_CMD $COMPOSE_FILES up tmkms node -d --no-deps; then
        echo ""
        echo -e "${GREEN}✓ 初始服务启动成功${NC}"
        echo ""
    else
        echo ""
        echo -e "${RED}[错误] 初始服务启动失败${NC}"
        echo -e "${YELLOW}[提示] 请检查配置和 Docker 状态${NC}"
        echo ""
        cd "$ORIGINAL_DIR"
        read -p "按 Enter 键返回主菜单..."
        return 1
    fi
    
    # 验证服务是否启动
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   验证服务状态${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "${GREEN}[步骤] 正在查看服务日志（观察3秒）...${NC}"
    echo ""
    
    # 使用 timeout 命令观察日志3秒
    if command -v timeout &> /dev/null; then
        timeout 3 $DOCKER_COMPOSE_CMD $COMPOSE_FILES logs tmkms node -f 2>/dev/null || true
    else
        # 如果没有 timeout 命令，使用 sleep 和后台任务
        $DOCKER_COMPOSE_CMD $COMPOSE_FILES logs tmkms node -f &
        LOG_PID=$!
        sleep 3
        kill $LOG_PID 2>/dev/null || true
    fi
    
    echo ""
    echo -e "${GREEN}✓ 服务日志查看完成${NC}"
    echo ""
    
    # 返回原目录
    cd "$ORIGINAL_DIR"
    
    echo ""
    read -p "按 Enter 键返回主菜单..."
}

# 命令4：检查同步状态
command4_check_sync_status() {
    clear
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   命令4：检查同步状态${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    # 保存当前工作目录
    ORIGINAL_DIR=$(pwd)
    
    # 确定配置目录路径
    if [ "$EUID" -eq 0 ]; then
        CONFIG_DIR="/root/gonka/deploy/join"
    else
        CONFIG_DIR="$HOME/gonka/deploy/join"
    fi
    
    # 检查配置目录是否存在
    if [ ! -d "$CONFIG_DIR" ]; then
        echo -e "${RED}[错误] 未找到配置目录: $CONFIG_DIR${NC}"
        echo -e "${YELLOW}[提示] 请先执行命令1：部署环境${NC}"
        echo ""
        read -p "按 Enter 键返回主菜单..."
        return 1
    fi
    
    # 进入配置目录
    cd "$CONFIG_DIR" || {
        echo -e "${RED}[错误] 无法进入配置目录${NC}"
        cd "$ORIGINAL_DIR"
        read -p "按 Enter 键返回主菜单..."
        return 1
    }
    
    # 检查 docker 是否可用
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}[错误] Docker 未安装${NC}"
        echo -e "${YELLOW}[提示] 请先执行命令1：部署环境${NC}"
        echo ""
        cd "$ORIGINAL_DIR"
        read -p "按 Enter 键返回主菜单..."
        return 1
    fi
    
    # 使用 sudo 或直接运行，取决于用户是否在 docker 组中或是否为 root
    DOCKER_COMPOSE_CMD="docker compose"
    if [ "$EUID" -ne 0 ] && ! groups | grep -q docker; then
        DOCKER_COMPOSE_CMD="sudo docker compose"
    fi
    
    echo -e "${GREEN}[步骤] 正在查看同步状态日志...${NC}"
    echo -e "${YELLOW}[提示] 将显示 tmkms 和 node 服务的日志，等待10秒后可按任意键返回${NC}"
    echo ""
    
    # 显示日志（后台运行）
    $DOCKER_COMPOSE_CMD logs tmkms node -f &
    LOG_PID=$!
    
    # 等待10秒
    sleep 10
    
    # 停止日志显示
    kill $LOG_PID 2>/dev/null || true
    
    echo ""
    echo -e "${GREEN}✓ 日志查看完成${NC}"
    echo ""
    
    # 返回原目录
    cd "$ORIGINAL_DIR"
    
    echo ""
    read -p "按任意键返回主菜单..."
}

# 命令5：创建 ML 操作密钥
command5_create_ml_key() {
    clear
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   命令4：创建 ML 操作密钥${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    # 保存当前工作目录
    ORIGINAL_DIR=$(pwd)
    
    # 确定配置目录路径
    if [ "$EUID" -eq 0 ]; then
        CONFIG_DIR="/root/gonka/deploy/join"
    else
        CONFIG_DIR="$HOME/gonka/deploy/join"
    fi
    
    # 检查配置目录是否存在
    if [ ! -d "$CONFIG_DIR" ]; then
        echo -e "${RED}[错误] 未找到配置目录: $CONFIG_DIR${NC}"
        echo -e "${YELLOW}[提示] 请先执行命令1：部署环境${NC}"
        echo ""
        read -p "按 Enter 键返回主菜单..."
        return 1
    fi
    
    # 检查配置文件是否存在
    CONFIG_FILE="$CONFIG_DIR/config.env"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}[错误] 未找到配置文件: $CONFIG_FILE${NC}"
        echo -e "${YELLOW}[提示] 请先执行命令3：配置环境变量${NC}"
        echo ""
        read -p "按 Enter 键返回主菜单..."
        return 1
    fi
    
    # 进入配置目录
    cd "$CONFIG_DIR" || {
        echo -e "${RED}[错误] 无法进入配置目录${NC}"
        read -p "按 Enter 键返回主菜单..."
        return 1
    }
    
    # 加载配置
    echo -e "${GREEN}[步骤] 正在加载配置文件...${NC}"
    if source config.env; then
        echo -e "${GREEN}✓ 配置文件加载成功${NC}"
    else
        echo -e "${RED}[错误] 配置文件加载失败${NC}"
        cd "$ORIGINAL_DIR"
        read -p "按 Enter 键返回主菜单..."
        return 1
    fi
    echo ""
    
    # 检查必要的环境变量
    if [ -z "$KEY_NAME" ] || [ -z "$KEYRING_PASSWORD" ] || [ -z "$ACCOUNT_PUBKEY" ]; then
        echo -e "${RED}[错误] 配置文件中缺少必要的环境变量${NC}"
        echo -e "${YELLOW}[提示] 请先执行命令3：配置环境变量${NC}"
        echo ""
        cd "$ORIGINAL_DIR"
        read -p "按 Enter 键返回主菜单..."
        return 1
    fi
    
    # 检查 DAPI 相关环境变量
    if [ -z "$DAPI_API__PUBLIC_URL" ] || [ -z "$DAPI_CHAIN_NODE__SEED_API_URL" ]; then
        echo -e "${YELLOW}[警告] 配置文件中缺少 DAPI 相关环境变量${NC}"
        echo -e "${YELLOW}[提示] 将使用默认值或从配置文件中读取${NC}"
        echo ""
    fi
    
    # 检查 docker 是否可用
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}[错误] Docker 未安装${NC}"
        echo -e "${YELLOW}[提示] 请先执行命令1：部署环境${NC}"
        echo ""
        cd "$ORIGINAL_DIR"
        read -p "按 Enter 键返回主菜单..."
        return 1
    fi
    
    # 检查 docker-compose.yml 文件是否存在
    if [ ! -f "docker-compose.yml" ]; then
        echo -e "${RED}[错误] 未找到 docker-compose.yml 文件${NC}"
        echo ""
        cd "$ORIGINAL_DIR"
        read -p "按 Enter 键返回主菜单..."
        return 1
    fi
    
    # 显示重要提示
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}   重要提示${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo ""
    echo -e "${YELLOW}不要重复执行此命令，每台服务器生成一次，必须在重启后保持${NC}"
    echo ""
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}   记录 ML 操作密钥地址${NC}"
    echo -e "${RED}========================================${NC}"
    echo ""
    
    read -p "我已理解上述提示，按 Enter 键继续创建 ML 操作密钥..."
    echo ""
    
    # 使用 sudo 或直接运行，取决于用户是否在 docker 组中或是否为 root
    DOCKER_COMPOSE_CMD="docker compose"
    if [ "$EUID" -ne 0 ] && ! groups | grep -q docker; then
        DOCKER_COMPOSE_CMD="sudo docker compose"
    fi
    
    # 从 config.env 文件中提取所有环境变量并构建 -e 参数
    ENV_ARGS=""
    while IFS= read -r line || [ -n "$line" ]; do
        # 跳过空行和注释
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        # 处理 export VAR=value 格式
        if [[ "$line" =~ ^[[:space:]]*export[[:space:]]+([^=]+)=(.*)$ ]]; then
            VAR_NAME="${BASH_REMATCH[1]// /}"
            VAR_VALUE="${BASH_REMATCH[2]}"
            # 移除可能的引号
            VAR_VALUE="${VAR_VALUE#\"}"
            VAR_VALUE="${VAR_VALUE%\"}"
            VAR_VALUE="${VAR_VALUE#\'}"
            VAR_VALUE="${VAR_VALUE%\'}"
            # 构建 -e 参数
            ENV_ARGS="$ENV_ARGS -e $VAR_NAME=$VAR_VALUE"
        # 处理 VAR=value 格式（没有 export）
        elif [[ "$line" =~ ^[[:space:]]*([^=]+)=(.*)$ ]]; then
            VAR_NAME="${BASH_REMATCH[1]// /}"
            VAR_VALUE="${BASH_REMATCH[2]}"
            # 移除可能的引号
            VAR_VALUE="${VAR_VALUE#\"}"
            VAR_VALUE="${VAR_VALUE%\"}"
            VAR_VALUE="${VAR_VALUE#\'}"
            VAR_VALUE="${VAR_VALUE%\'}"
            # 构建 -e 参数
            ENV_ARGS="$ENV_ARGS -e $VAR_NAME=$VAR_VALUE"
        fi
    done < config.env
    
    # 确定种子节点地址（用于注册主机）
    if [ -z "$SEED_API_URL" ]; then
        SEED_NODE_ADDRESS="http://node2.gonka.ai:8000"
    else
        SEED_NODE_ADDRESS="$SEED_API_URL"
    fi
    
    # 执行命令：创建密钥
    echo -e "${GREEN}[步骤] 正在创建 ML 操作密钥...${NC}"
    echo -e "${YELLOW}[提示] 正在进入 API 容器...${NC}"
    echo ""
    
    CREATE_KEY_CMD="printf '%s\n%s\n' \"\$KEYRING_PASSWORD\" \"\$KEYRING_PASSWORD\" | inferenced keys add \"\$KEY_NAME\" --keyring-backend file"
    
    # 先执行创建密钥命令
    if $DOCKER_COMPOSE_CMD run --rm --no-deps -it $ENV_ARGS api /bin/sh -c "$CREATE_KEY_CMD"; then
        echo ""
        echo -e "${GREEN}✓ ML 操作密钥创建成功${NC}"
        echo ""
        
        # 获取刚创建的密钥地址（从输出中提取）
        echo -e "${GREEN}[步骤] 正在注册主机...${NC}"
        echo ""
        
        # 确定节点URL（使用 PUBLIC_URL，如果没有则使用 SEED_API_URL）
        if [ -z "$PUBLIC_URL" ]; then
            if [ -z "$SEED_API_URL" ]; then
                NODE_URL="http://node2.gonka.ai:8000"
            else
                NODE_URL="$SEED_API_URL"
            fi
        else
            NODE_URL="$PUBLIC_URL"
        fi
        
        # 确定种子节点地址
        if [ -z "$SEED_API_URL" ]; then
            SEED_NODE_ADDRESS="http://node2.gonka.ai:8000"
        else
            SEED_NODE_ADDRESS="$SEED_API_URL"
        fi
        
        echo -e "${CYAN}[信息] 节点URL: $NODE_URL${NC}"
        echo -e "${CYAN}[信息] 种子节点地址: $SEED_NODE_ADDRESS${NC}"
        echo ""
        
        # 执行注册主机命令
        # 根据错误信息，命令格式应该是：register-new-participant <node-url> <account-public-key> --node-address <seed-node>
        # <node-url> 应该是公共节点URL，<account-public-key> 是账户公钥，--node-address 是种子节点地址
        # 直接在命令中使用变量值，而不是环境变量引用
        REGISTER_CMD="inferenced register-new-participant \"$NODE_URL\" \"$ACCOUNT_PUBKEY\" --node-address \"$SEED_NODE_ADDRESS\""
        
        if $DOCKER_COMPOSE_CMD run --rm --no-deps -it $ENV_ARGS api /bin/sh -c "$REGISTER_CMD"; then
            echo ""
            echo -e "${GREEN}========================================${NC}"
            echo -e "${GREEN}   ML 操作密钥创建和主机注册成功！${NC}"
            echo -e "${GREEN}========================================${NC}"
            echo ""
            echo -e "${RED}========================================${NC}"
            echo -e "${RED}   请记录 ML 操作密钥地址${NC}"
            echo -e "${RED}========================================${NC}"
            echo ""
            echo -e "${CYAN}密钥信息：${NC}"
            echo -e "${GREEN}  密钥名称: $KEY_NAME${NC}"
            echo -e "${GREEN}  密钥类型: file${NC}"
            echo -e "${GREEN}  账户公钥: $ACCOUNT_PUBKEY${NC}"
            echo ""
            echo -e "${YELLOW}[提示] 请确保已记录密钥地址，这是重要的安全信息${NC}"
            echo ""
        else
            echo ""
            echo -e "${YELLOW}[警告] 主机注册失败，但密钥已创建${NC}"
            echo -e "${YELLOW}[提示] 您可以稍后手动执行注册命令${NC}"
            echo -e "${YELLOW}[提示] 注册命令: inferenced register-new-participant <node-url> <account-public-key> --node-address <seed-node>${NC}"
            echo ""
            echo -e "${GREEN}✓ ML 操作密钥已创建，请记录密钥地址${NC}"
            echo ""
        fi
    else
        echo ""
        echo -e "${RED}[错误] ML 操作密钥创建失败${NC}"
        echo -e "${YELLOW}[提示] 请检查错误信息并重试${NC}"
        echo ""
        cd "$ORIGINAL_DIR"
        read -p "按 Enter 键返回主菜单..."
        return 1
    fi
    
    # 授权权限
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   授权权限${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    echo -e "${YELLOW}▲ 重要: 在您创建账户密钥的安全本地机器上执行此步骤${NC}"
    echo ""
    
    # 获取用户输入的热钱包地址
    echo -e "${CYAN}请输入创建 ML 操作密钥时的热钱包地址：${NC}"
    while [ -z "$ML_OPS_WALLET_ADDRESS" ]; do
        read -p "热钱包地址: " ML_OPS_WALLET_ADDRESS
        if [ -z "$ML_OPS_WALLET_ADDRESS" ]; then
            echo -e "${RED}   [错误] 热钱包地址不能为空，请重新输入${NC}"
        fi
    done
    echo -e "${GREEN}   ✓ 热钱包地址: $ML_OPS_WALLET_ADDRESS${NC}"
    echo ""
    
    # 确定 gonka 目录
    if [ "$EUID" -eq 0 ]; then
        GONKA_DIR="/root/gonka"
    else
        GONKA_DIR="$HOME/gonka"
    fi
    
    # 进入 gonka 目录执行命令
    if [ ! -d "$GONKA_DIR" ]; then
        echo -e "${RED}[错误] 未找到 gonka 目录: $GONKA_DIR${NC}"
        echo -e "${YELLOW}[提示] 请先执行命令1：部署环境${NC}"
        echo ""
        cd "$ORIGINAL_DIR"
        read -p "按 Enter 键返回主菜单..."
        return 1
    fi
    
    cd "$GONKA_DIR" || {
        echo -e "${RED}[错误] 无法进入 gonka 目录${NC}"
        cd "$ORIGINAL_DIR"
        read -p "按 Enter 键返回主菜单..."
        return 1
    }
    
    # 检查 inferenced 是否可用
    if command -v inferenced &> /dev/null; then
        INFERENCED_CMD="inferenced"
    elif [ -f "./inferenced" ]; then
        INFERENCED_CMD="./inferenced"
    else
        echo -e "${RED}[错误] 未找到 inferenced 命令${NC}"
        echo -e "${YELLOW}[提示] 请先执行命令1：部署环境${NC}"
        echo ""
        cd "$ORIGINAL_DIR"
        read -p "按 Enter 键返回主菜单..."
        return 1
    fi
    
    # 使用固定的账户密钥名称（命令2创建的）
    ACCOUNT_KEY_NAME="gonka-account-key"
    
    # 提示用户确认密钥存在（避免检查命令卡住）
    echo -e "${YELLOW}[提示] 请确保已执行命令2创建账户密钥 '$ACCOUNT_KEY_NAME'${NC}"
    echo ""
    
    # 加载配置（设置 SEED_API_URL 环境变量）
    echo -e "${GREEN}[步骤] 正在加载配置（设置环境变量）...${NC}"
    if [ -f "$CONFIG_DIR/config.env" ]; then
        source "$CONFIG_DIR/config.env"
    fi
    
    # 检查并设置 SEED_API_URL
    if [ -z "$SEED_API_URL" ]; then
        # 如果未设置，使用默认值
        SEED_API_URL="http://node2.gonka.ai:8000"
        echo -e "${YELLOW}[信息] SEED_API_URL 未设置，使用默认值: $SEED_API_URL${NC}"
    fi
    
    export SEED_API_URL
    echo -e "${GREEN}✓ SEED_API_URL: $SEED_API_URL${NC}"
    echo ""
    
    # 执行授权权限命令
    echo -e "${GREEN}[步骤] 正在执行授权权限命令...${NC}"
    echo ""
    
    # 构建节点URL（去掉末尾的斜杠，如果有的话）
    NODE_URL="${SEED_API_URL%/}/chain-rpc/"
    
    echo -e "${CYAN}[信息] 执行命令：${NC}"
    echo -e "${CYAN}  $INFERENCED_CMD tx inference grant-ml-ops-permissions \\${NC}"
    echo -e "${CYAN}    $ACCOUNT_KEY_NAME \\${NC}"
    echo -e "${CYAN}    $ML_OPS_WALLET_ADDRESS \\${NC}"
    echo -e "${CYAN}    --from $ACCOUNT_KEY_NAME \\${NC}"
    echo -e "${CYAN}    --keyring-backend file \\${NC}"
    echo -e "${CYAN}    --gas 2000000 \\${NC}"
    echo -e "${CYAN}    --node $NODE_URL${NC}"
    echo ""
    
    if $INFERENCED_CMD tx inference grant-ml-ops-permissions \
        "$ACCOUNT_KEY_NAME" \
        "$ML_OPS_WALLET_ADDRESS" \
        --from "$ACCOUNT_KEY_NAME" \
        --keyring-backend file \
        --gas 2000000 \
        --node "$NODE_URL"; then
        echo ""
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}   授权权限成功！${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo ""
        echo -e "${CYAN}授权信息：${NC}"
        echo -e "${GREEN}  账户密钥: $ACCOUNT_KEY_NAME${NC}"
        echo -e "${GREEN}  热钱包地址: $ML_OPS_WALLET_ADDRESS${NC}"
        echo -e "${GREEN}  节点地址: $NODE_URL${NC}"
        echo ""
    else
        echo ""
        echo -e "${RED}[错误] 授权权限失败${NC}"
        echo -e "${YELLOW}[提示] 请检查：${NC}"
        echo -e "${YELLOW}  1. 账户密钥 '$ACCOUNT_KEY_NAME' 是否存在（执行命令2）${NC}"
        echo -e "${YELLOW}  2. 热钱包地址是否正确${NC}"
        echo -e "${YELLOW}  3. 网络连接是否正常${NC}"
        echo -e "${YELLOW}  4. SEED_API_URL 是否正确${NC}"
        echo ""
    fi
    
    # 返回原目录
    cd "$ORIGINAL_DIR"
    
    echo ""
    read -p "按 Enter 键返回主菜单..."
}

# 命令6：启动全节点
command6_start_full_node() {
    clear
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   命令5：启动全节点${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    # 保存当前工作目录
    ORIGINAL_DIR=$(pwd)
    
    # 确定配置目录路径
    if [ "$EUID" -eq 0 ]; then
        CONFIG_DIR="/root/gonka/deploy/join"
    else
        CONFIG_DIR="$HOME/gonka/deploy/join"
    fi
    
    # 检查配置目录是否存在
    if [ ! -d "$CONFIG_DIR" ]; then
        echo -e "${RED}[错误] 未找到配置目录: $CONFIG_DIR${NC}"
        echo -e "${YELLOW}[提示] 请先执行命令1：部署环境${NC}"
        echo ""
        read -p "按 Enter 键返回主菜单..."
        return 1
    fi
    
    # 检查配置文件是否存在
    CONFIG_FILE="$CONFIG_DIR/config.env"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}[错误] 未找到配置文件: $CONFIG_FILE${NC}"
        echo -e "${YELLOW}[提示] 请先执行命令3：配置环境变量${NC}"
        echo ""
        read -p "按 Enter 键返回主菜单..."
        return 1
    fi
    
    # 进入配置目录
    cd "$CONFIG_DIR" || {
        echo -e "${RED}[错误] 无法进入配置目录${NC}"
        read -p "按 Enter 键返回主菜单..."
        return 1
    }
    
    # 检查 docker 是否可用
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}[错误] Docker 未安装${NC}"
        echo -e "${YELLOW}[提示] 请先执行命令1：部署环境${NC}"
        echo ""
        cd "$ORIGINAL_DIR"
        read -p "按 Enter 键返回主菜单..."
        return 1
    fi
    
    # 检查 docker-compose.yml 文件是否存在
    if [ ! -f "docker-compose.yml" ]; then
        echo -e "${RED}[错误] 未找到 docker-compose.yml 文件${NC}"
        echo ""
        cd "$ORIGINAL_DIR"
        read -p "按 Enter 键返回主菜单..."
        return 1
    fi
    
    # 检查 docker-compose.mlnode.yml 文件是否存在
    if [ ! -f "docker-compose.mlnode.yml" ]; then
        echo -e "${YELLOW}[警告] 未找到 docker-compose.mlnode.yml 文件${NC}"
        echo -e "${YELLOW}[提示] 将只使用 docker-compose.yml${NC}"
        COMPOSE_FILES="-f docker-compose.yml"
    else
        COMPOSE_FILES="-f docker-compose.yml -f docker-compose.mlnode.yml"
    fi
    
    # 使用 sudo 或直接运行，取决于用户是否在 docker 组中或是否为 root
    DOCKER_COMPOSE_CMD="docker compose"
    if [ "$EUID" -ne 0 ] && ! groups | grep -q docker; then
        DOCKER_COMPOSE_CMD="sudo docker compose"
    fi
    
    # 加载配置并启动全节点
    echo -e "${GREEN}[步骤] 正在加载配置文件...${NC}"
    if source config.env; then
        echo -e "${GREEN}✓ 配置文件加载成功${NC}"
    else
        echo -e "${RED}[错误] 配置文件加载失败${NC}"
        cd "$ORIGINAL_DIR"
        read -p "按 Enter 键返回主菜单..."
        return 1
    fi
    echo ""
    
    # 修改 docker-compose.yml 文件中的 BEACON_STATE_URL
    echo -e "${GREEN}[步骤] 正在修改 docker-compose.yml 配置...${NC}"
    DOCKER_COMPOSE_FILE="docker-compose.yml"
    if [ -f "$DOCKER_COMPOSE_FILE" ]; then
        # 检查是否需要修改（支持各种格式：带引号、不带引号、带空格等）
        if grep -q "BEACON_STATE_URL.*beaconstate\.ethstaker\.cc" "$DOCKER_COMPOSE_FILE"; then
            # 使用 sed 进行替换（创建临时文件后替换，更安全）
            # 匹配各种可能的格式：https://beaconstate.ethstaker.cc/ 或 https://beaconstate.ethstaker.cc
            TEMP_FILE=$(mktemp)
            if sed -E 's|(BEACON_STATE_URL=.*)https://beaconstate\.ethstaker\.cc/?|\1https://beaconstate.info/|g' "$DOCKER_COMPOSE_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$DOCKER_COMPOSE_FILE"; then
                echo -e "${GREEN}✓ BEACON_STATE_URL 已更新为 https://beaconstate.info/${NC}"
            else
                rm -f "$TEMP_FILE"
                echo -e "${YELLOW}[警告] BEACON_STATE_URL 更新失败，继续执行...${NC}"
            fi
        else
            echo -e "${YELLOW}[信息] BEACON_STATE_URL 配置未找到或已更新${NC}"
        fi
    else
        echo -e "${YELLOW}[警告] 未找到 docker-compose.yml 文件${NC}"
    fi
    echo ""
    
    echo -e "${GREEN}[步骤] 正在启动全节点...${NC}"
    echo -e "${YELLOW}[提示] 这可能需要一些时间，请耐心等待...${NC}"
    echo ""
    
    if $DOCKER_COMPOSE_CMD $COMPOSE_FILES up -d; then
        echo ""
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}   全节点启动成功！${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo ""
        
        # 显示服务状态
        echo -e "${CYAN}服务状态：${NC}"
        $DOCKER_COMPOSE_CMD $COMPOSE_FILES ps
        echo ""
        
        echo -e "${YELLOW}[提示] 可以使用以下命令查看服务状态：${NC}"
        echo -e "${GREEN}   docker compose ps${NC}"
        echo -e "${GREEN}   docker compose logs -f${NC}"
        echo ""
    else
        echo ""
        echo -e "${RED}[错误] 全节点启动失败${NC}"
        echo -e "${YELLOW}[提示] 请检查错误信息并重试${NC}"
        echo ""
    fi
    
    # 返回原目录
    cd "$ORIGINAL_DIR"
    
    echo ""
    read -p "按 Enter 键返回主菜单..."
}

# 命令7：验证节点状态
command7_verify_node_status() {
    clear
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   命令6：验证节点状态${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    # 保存当前工作目录
    ORIGINAL_DIR=$(pwd)
    
    # 确定配置目录路径
    if [ "$EUID" -eq 0 ]; then
        CONFIG_DIR="/root/gonka/deploy/join"
    else
        CONFIG_DIR="$HOME/gonka/deploy/join"
    fi
    
    # 检查配置目录是否存在
    if [ ! -d "$CONFIG_DIR" ]; then
        echo -e "${RED}[错误] 未找到配置目录: $CONFIG_DIR${NC}"
        echo -e "${YELLOW}[提示] 请先执行命令1：部署环境${NC}"
        echo ""
        read -p "按 Enter 键返回主菜单..."
        return 1
    fi
    
    # 检查配置文件是否存在
    CONFIG_FILE="$CONFIG_DIR/config.env"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}[错误] 未找到配置文件: $CONFIG_FILE${NC}"
        echo -e "${YELLOW}[提示] 请先执行命令3：配置环境变量${NC}"
        echo ""
        read -p "按 Enter 键返回主菜单..."
        return 1
    fi
    
    # 进入配置目录
    cd "$CONFIG_DIR" || {
        echo -e "${RED}[错误] 无法进入配置目录${NC}"
        read -p "按 Enter 键返回主菜单..."
        return 1
    }
    
    # 加载配置
    echo -e "${GREEN}[步骤] 正在加载配置文件...${NC}"
    if source config.env; then
        echo -e "${GREEN}✓ 配置文件加载成功${NC}"
    else
        echo -e "${RED}[错误] 配置文件加载失败${NC}"
        cd "$ORIGINAL_DIR"
        read -p "按 Enter 键返回主菜单..."
        return 1
    fi
    echo ""
    
    # 获取用户输入的钱包地址
    echo -e "${CYAN}请输入您的 gonka 冷钱包地址：${NC}"
    echo -e "${YELLOW}   这是您在命令2中创建的钱包地址${NC}"
    echo ""
    while [ -z "$GONKA_COLD_ADDRESS" ]; do
        read -p "钱包地址: " GONKA_COLD_ADDRESS
        if [ -z "$GONKA_COLD_ADDRESS" ]; then
            echo -e "${RED}   [错误] 钱包地址不能为空，请重新输入${NC}"
        fi
    done
    echo -e "${GREEN}   ✓ 钱包地址: $GONKA_COLD_ADDRESS${NC}"
    echo ""
    
    # 确定 SEED API URL
    if [ ! -z "$SEED_API_URL" ]; then
        SEED_API_BASE="$SEED_API_URL"
    else
        SEED_API_BASE="http://node2.gonka.ai:8000"
    fi
    
    # 生成验证地址
    VERIFY_URL="$SEED_API_BASE/v1/participants/$GONKA_COLD_ADDRESS"
    
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   节点状态验证地址${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "${GREEN}请复制以下地址到浏览器中打开，以验证节点状态：${NC}"
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}$VERIFY_URL${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${CYAN}使用说明：${NC}"
    echo -e "${YELLOW}  1. 复制上面的地址${NC}"
    echo -e "${YELLOW}  2. 在浏览器中打开该地址${NC}"
    echo -e "${YELLOW}  3. 查看节点状态信息${NC}"
    echo ""
    
    # 尝试使用 curl 验证（如果可用）
    if command -v curl &> /dev/null; then
        echo -e "${GREEN}[步骤] 正在尝试验证节点状态...${NC}"
        echo ""
        if curl -s -f "$VERIFY_URL" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ 节点状态验证地址可访问${NC}"
            echo ""
            echo -e "${CYAN}节点状态信息：${NC}"
            curl -s "$VERIFY_URL" | head -n20 || echo -e "${YELLOW}   无法解析响应内容${NC}"
            echo ""
        else
            echo -e "${YELLOW}[警告] 无法访问验证地址${NC}"
            echo -e "${YELLOW}[提示] 请检查：${NC}"
            echo -e "${YELLOW}   1. 节点服务是否已启动（执行命令6）${NC}"
            echo -e "${YELLOW}   2. 网络连接是否正常${NC}"
            echo -e "${YELLOW}   3. 钱包地址是否正确${NC}"
            echo ""
        fi
    else
        echo -e "${YELLOW}[提示] 未安装 curl，无法自动验证${NC}"
        echo -e "${YELLOW}[提示] 请手动在浏览器中打开上述地址进行验证${NC}"
        echo ""
    fi
    
    # 返回原目录
    cd "$ORIGINAL_DIR"
    
    echo ""
    read -p "按 Enter 键返回主菜单..."
}

# 显示主菜单
show_main_menu() {
    clear
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   Gonka 部署管理脚本 (Ubuntu)${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "${GREEN}推特: @ferdie_jhovie${NC}"
    echo -e "${RED}请勿相信收费脚本，本脚本免费开源${NC}"
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "${GREEN}请选择要执行的操作：${NC}"
    echo ""
    echo -e "${YELLOW}  1. 部署环境${NC}"
    echo -e "${YELLOW}      - 安装 Docker${NC}"
    echo -e "${YELLOW}      - 配置 GPU 支持${NC}"
    echo -e "${YELLOW}      - 安装 HuggingFace CLI${NC}"
    echo -e "${YELLOW}      - 下载部署文件${NC}"
    echo -e "${YELLOW}      - 安装 inferenced${NC}"
    echo ""
    echo -e "${YELLOW}  2. 创建钱包${NC}"
    echo -e "${YELLOW}      - 创建 gonka 账户密钥${NC}"
    echo ""
    echo -e "${YELLOW}  3. 配置环境变量${NC}"
    echo -e "${YELLOW}      - 配置节点名称、密码、端口等${NC}"
    echo ""
    echo -e "${YELLOW}  4. 检查同步状态${NC}"
    echo -e "${YELLOW}      - 查看 tmkms 和 node 服务日志${NC}"
    echo ""
    echo -e "${YELLOW}  5. 创建 ML 操作密钥${NC}"
    echo -e "${YELLOW}      - 在 API 容器中创建 ML 操作密钥${NC}"
    echo ""
    echo -e "${YELLOW}  6. 启动全节点${NC}"
    echo -e "${YELLOW}      - 启动所有 Docker 服务${NC}"
    echo ""
    echo -e "${YELLOW}  7. 验证节点状态${NC}"
    echo -e "${YELLOW}      - 生成验证地址并检查节点状态${NC}"
    echo ""
    echo -e "${YELLOW}  0. 退出${NC}"
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo ""
}

# 主函数
main() {
    while true; do
        show_main_menu
        read -p "请输入选项 [0-7]: " choice
        echo ""
        
        case $choice in
            1)
                command1_deploy_environment
                ;;
            2)
                command2_create_wallet
                ;;
            3)
                command3_configure_env
                ;;
            4)
                command4_check_sync_status
                ;;
            5)
                command5_create_ml_key
                ;;
            6)
                command6_start_full_node
                ;;
            7)
                command7_verify_node_status
                ;;
            0)
                echo -e "${GREEN}感谢使用，再见！${NC}"
                echo ""
                exit 0
                ;;
            *)
                echo -e "${RED}[错误] 无效的选项，请重新选择${NC}"
                echo ""
                read -p "按 Enter 键继续..."
                ;;
        esac
    done
}

# 运行主函数
main


