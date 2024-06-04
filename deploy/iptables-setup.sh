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
ENV_FILE="$SCRIPT_DIR/env/.env.iptables-setup"

echo -e "${BRIGHT_BLUE}iptables Setup Start.${RESET}"

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

# iptablesのインストール
echo -e "${BRIGHT_BLUE}Installing iptables...${RESET}"
if [ "$OS" = "ubuntu" ]; then
    $PKG_MANAGER install -y iptables
elif [ "$OS" = "centos" ]; then
    $PKG_MANAGER install -y iptables-services
fi

# firewalldの停止と無効化
if [ "$OS" = "centos" ]; then
    echo -e "${BRIGHT_BLUE}Disabling firewalld...${RESET}"
    if systemctl is-active --quiet firewalld; then
        systemctl stop firewalld
        systemctl disable firewalld
    else
        echo -e "${BRIGHT_YELLOW}firewalld is not active. Skipping disable step.${RESET}"
    fi
fi

# iptablesサービスの有効化と開始
if [ "$OS" = "centos" ]; then
    echo -e "${BRIGHT_BLUE}Enabling and starting iptables...${RESET}"
    systemctl enable iptables
    if ! systemctl start iptables; then
        echo -e "${BRIGHT_RED}Failed to start iptables service. Attempting manual start...${RESET}"
        iptables &
    fi
fi

echo -e "${BRIGHT_BLUE}Initializing iptables...${RESET}"
# 既存のルールをクリア
iptables -F
iptables -X

# 必要なモジュールのロード
modprobe xt_conntrack
modprobe nf_conntrack

# デフォルトポリシーを設定
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# DOCKERチェーンの手動作成（既に存在する場合はスキップ）
iptables -N DOCKER 2>/dev/null

# HTTPおよびHTTPSトラフィックの許可
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Dockerインターフェースへのトラフィックの許可
iptables -A FORWARD -o docker0 -j DOCKER
iptables -A FORWARD -i docker0 -j ACCEPT
iptables -A FORWARD -o br-918b2a66b087 -j DOCKER

# ループバックインターフェースのトラフィックを許可
iptables -A INPUT -i lo -j ACCEPT

# 既に確立された接続を許可
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# ping (ICMP echo requests) を許可
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT

# その他のトラフィックを拒否
iptables -A INPUT -j DROP

# Dockerインターフェースを有効化
ip link set docker0 up

# iptablesルールの保存
if command -v service &> /dev/null; then
    service iptables save
else
    echo -e "${BRIGHT_RED}service command not found. Skipping iptables rules save.${RESET}"
fi

# iptablesサービスの再起動
if command -v systemctl &> /dev/null; then
    systemctl restart iptables || {
        echo -e "${BRIGHT_RED}Failed to restart iptables service. Attempting manual restart...${RESET}"
        iptables &
    }
else
    echo -e "${BRIGHT_YELLOW}systemctl is not available. Skipping iptables service restart.${RESET}"
fi

if command -v systemctl &> /dev/null; then
    systemctl restart docker || {
        echo -e "${BRIGHT_RED}Failed to restart docker service.${RESET}"
    }
else
    echo -e "${BRIGHT_YELLOW}systemctl is not available. Skipping docker service restart.${RESET}"
fi

echo -e "${BRIGHT_GREEN}iptables Setup Successfully.${RESET}"
