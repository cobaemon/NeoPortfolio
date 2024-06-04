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

echo -e "${BRIGHT_CYAN}Deploy Start.${RESET}"

echo -e "${BRIGHT_CYAN}Setting execute permissions for deploy directory scripts...${RESET}"
chmod +x "${SCRIPT_DIR}/deploy/initialization.sh"
chmod +x "${SCRIPT_DIR}/deploy/systemclock-setup.sh"
chmod +x "${SCRIPT_DIR}/deploy/docker-setup.sh"
chmod +x "${SCRIPT_DIR}/deploy/iptables-setup.sh"
chmod +x "${SCRIPT_DIR}/deploy/openssl-setup.sh"
chmod +x "${SCRIPT_DIR}/deploy/nginx-setup.sh"
chmod +x "${SCRIPT_DIR}/deploy/certbot-setup.sh"
chmod +x "${SCRIPT_DIR}/deploy/encode-certs.sh"
chmod +x "${SCRIPT_DIR}/deploy/update-certs-and-restart-container.sh"

# 初期化
bash "${SCRIPT_DIR}/deploy/initialization.sh"

# Dockerの設定
bash "${SCRIPT_DIR}/deploy/docker-setup.sh"

# systemctlの設定
bash "${SCRIPT_DIR}/deploy/systemclock-setup.sh"

# iptablesの設定
bash "${SCRIPT_DIR}/deploy/iptables-setup.sh"

# opensslの設定
bash "${SCRIPT_DIR}/deploy/openssl-setup.sh"

# nginxの設定
bash "${SCRIPT_DIR}/deploy/nginx-setup.sh"

# certbotの設定
bash "${SCRIPT_DIR}/deploy/certbot-setup.sh"

echo -e "${BRIGHT_GREEN}Deployment completed successfully.${RESET}"
