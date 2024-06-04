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

echo -e "${BRIGHT_BLUE}AWS CLI Setup Start.${RESET}"

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

# AWS CLIのインストール
if ! command -v aws &> /dev/null; then
    echo -e "${BRIGHT_BLUE}AWS CLI not found. Installing AWS CLI...${RESET}"
    if [ "$PKG_MANAGER" = "yum" ]; then
        $PKG_MANAGER install -y awscli
    elif [ "$PKG_MANAGER" = "apt" ]; then
        $PKG_MANAGER install -y awscli
    fi
    echo -e "${BRIGHT_BLUE}AWS CLI installation completed.${RESET}"
else
    echo -e "${BRIGHT_YELLOW}AWS CLI is already installed.${RESET}"
fi

echo -e "${BRIGHT_GREEN}AWS CLI Setup Successfully.${RESET}"
