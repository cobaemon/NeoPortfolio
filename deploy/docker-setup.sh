#!/bin/bash

# エラー時にスクリプトを終了する
set -e

# 色の定義
BRIGHT_GREEN='\033[1;32m'
BRIGHT_YELLOW='\033[1;33m'
BRIGHT_BLUE='\033[1;34m'
BRIGHT_RED='\033[1;31m'
RESET='\033[0m'

# スクリプトのディレクトリを基準にパスを設定
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
ENV_FILE="$SCRIPT_DIR/env/.env.docker-setup"

echo -e "${BRIGHT_BLUE}Docker Setup Start.${RESET}"

# 環境変数ファイルの読み込み
if [ -f "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
else
    echo -e "${BRIGHT_RED}${ENV_FILE} file not found.${RESET}"
    exit 1
fi

# OSを検出
if [ -f /etc/lsb-release ]; then
    # Ubuntu
    PKG_MANAGER="apt"
    OS="ubuntu"
elif [ -f /etc/redhat-release ]; then
    # CentOS
    PKG_MANAGER="yum"
    OS="centos"
else
    echo -e "${BRIGHT_RED}Unsupported OS${RESET}"
    exit 1
fi

# 必要なパッケージの更新
echo -e "${BRIGHT_BLUE}Updating package list...${RESET}"
$PKG_MANAGER update -y

# Dockerのインストール
if ! command -v docker &> /dev/null; then
    echo -e "${BRIGHT_BLUE}Docker not found. Installing Docker...${RESET}"
    if [ "$PKG_MANAGER" = "yum" ]; then
        $PKG_MANAGER install -y yum-utils
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        $PKG_MANAGER install -y docker-ce docker-ce-cli containerd.io
    else
        $PKG_MANAGER install -y apt-transport-https ca-certificates curl software-properties-common
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
        add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        $PKG_MANAGER update
        $PKG_MANAGER install -y docker-ce docker-ce-cli containerd.io
    fi
    systemctl start docker
    systemctl enable docker
    echo -e "${BRIGHT_BLUE}Docker installation completed.${RESET}"
else
    echo -e "${BRIGHT_YELLOW}Docker is already installed.${RESET}"
fi

echo -e "${BRIGHT_GREEN}Docker Setup Successfully.${RESET}"
