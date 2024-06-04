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
ENV_FILE="$SCRIPT_DIR/env/.env.systemclock-setup"

echo -e "${BRIGHT_BLUE}Systemclock Setup Start.${RESET}"

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
    CHRONY_SERVICE="chrony"
elif [ -f /etc/redhat-release ]; then
    # CentOS
    PKG_MANAGER="yum"
    OS="centos"
    CHRONY_SERVICE="chronyd"
else
    echo -e "${BRIGHT_RED}Unsupported OS${RESET}"
    exit 1
fi

# 必要なパッケージの更新
echo -e "${BRIGHT_BLUE}Updating package list...${RESET}"
$PKG_MANAGER update -y

# Chronyのインストール
echo -e "${BRIGHT_BLUE}Installing Chrony...${RESET}"
$PKG_MANAGER install -y chrony

# systemctlの有無を確認
if command -v systemctl &> /dev/null; then
    echo -e "${BRIGHT_BLUE}Enabling and starting Chrony service...${RESET}"
    systemctl enable $CHRONY_SERVICE
    if ! systemctl start $CHRONY_SERVICE; then
        echo -e "${BRIGHT_RED}Failed to start $CHRONY_SERVICE service. Attempting manual start...${RESET}"
        $CHRONY_SERVICE
    fi
else
    echo -e "${BRIGHT_BLUE}systemctl is not available. Starting Chrony manually...${RESET}"
    $CHRONY_SERVICE
fi

# タイムゾーンを東京に変更
echo -e "${BRIGHT_BLUE}Changing timezone to Asia/Tokyo...${RESET}"
timedatectl set-timezone Asia/Tokyo || {
    echo -e "${BRIGHT_RED}Failed to set timezone using timedatectl. Attempting manual method...${RESET}"
    ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime
    echo "Asia/Tokyo" | tee /etc/timezone
}

# NTPの有効化
echo -e "${BRIGHT_BLUE}Enabling NTP synchronization...${RESET}"
timedatectl set-ntp true || {
    echo -e "${BRIGHT_RED}Failed to enable NTP using timedatectl.${RESET}"
}

# Chronyのステータスを確認
echo -e "${BRIGHT_BLUE}Chrony status:${RESET}"
if command -v chronyc &> /dev/null; then
    chronyc tracking || echo -e "${BRIGHT_RED}Failed to retrieve Chrony status.${RESET}"
else
    echo -e "${BRIGHT_YELLOW}chronyc command not found. Skipping Chrony status check.${RESET}"
fi

echo -e "${BRIGHT_GREEN}Systemclock Setup Successfully.${RESET}"
