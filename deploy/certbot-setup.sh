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
ENV_FILE="$SCRIPT_DIR/env/.env.certbot-setup"

echo -e "${BRIGHT_BLUE}Certbot Setup Start.${RESET}"

# 環境変数ファイルの読み込み
if [ -f "$ENV_FILE" ]; then
    echo -e "${BRIGHT_YELLOW}Loading environment variables from ${ENV_FILE}...${RESET}"
    set -a
    source "$ENV_FILE"
    set +a
else
    echo -e "${BRIGHT_RED}${ENV_FILE} file not found. Please ensure it exists in the script directory.${RESET}"
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

# Certbotのインストール
if ! command -v certbot &> /dev/null; then
    echo -e "${BRIGHT_YELLOW}Certbot not found. Installing Certbot...${RESET}"
    if [ "$PKG_MANAGER" = "yum" ]; then
        $PKG_MANAGER install -y epel-release
        $PKG_MANAGER install -y certbot python2-certbot-nginx
    elif [ "$PKG_MANAGER" = "apt" ]; then
        $PKG_MANAGER install -y certbot python3-certbot-nginx
    fi
    echo -e "${BRIGHT_GREEN}Certbot installation completed.${RESET}"
else
    echo -e "${BRIGHT_YELLOW}Certbot is already installed.${RESET}"
fi

# 証明書の存在を確認
echo -e "${BRIGHT_BLUE}Checking for existing certificates...${RESET}"
if certbot certificates --cert-name "$DOMAIN_NAME" > /dev/null 2>&1; then
    echo -e "${BRIGHT_YELLOW}Updating existing certificate for ${DOMAIN_NAME}...${RESET}"
    certbot renew --cert-name "$DOMAIN_NAME"
else
    echo -e "${BRIGHT_YELLOW}Obtaining new certificate for ${DOMAIN_NAME}...${RESET}"
    certbot --nginx -d "$DOMAIN_NAME" --non-interactive --agree-tos
fi

# 証明書を暗号化し.envを更新
bash "${SCRIPT_DIR}/encode-certs.sh"

# Certbotのフックスクリプトにupdate-certs-and-restart-container.shを追加
echo -e "${BRIGHT_BLUE}Adding Certbot deployment hook...${RESET}"
mkdir -p /etc/letsencrypt/renewal-hooks/deploy
ln -sf "$SCRIPT_DIR/update-certs-and-restart-container.sh" /etc/letsencrypt/renewal-hooks/deploy/update-certs-and-restart-container.sh
chmod +x /etc/letsencrypt/renewal-hooks/deploy/update-certs-and-restart-container.sh

echo -e "${BRIGHT_GREEN}Certbot Setup Successfully.${RESET}"
