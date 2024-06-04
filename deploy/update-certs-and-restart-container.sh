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
CERTS_ENV_FILE="$SCRIPT_DIR/env/.env.cert"
UPDATE_CERTS_ENV_FILE="$SCRIPT_DIR/env/.env.update-certs-and-restart-container"

# ログファイルのパス
LOG_FILE="/var/log/portfolio/cert_update.log"

# .env.certファイルの存在確認
if [ -f "$CERTS_ENV_FILE" ]; then
    set -a
    source "$CERTS_ENV_FILE"
    set +a
else
    echo -e "${BRIGHT_RED}${CERTS_ENV_FILE} file not found.${RESET}"
    exit 1
fi

# .env.update-certs-and-restart-containerファイルの存在確認
if [ -f "$UPDATE_CERTS_ENV_FILE" ]; then
    set -a
    source "$UPDATE_CERTS_ENV_FILE"
    set +a
else
    echo -e "${BRIGHT_RED}${UPDATE_CERTS_ENV_FILE} file not found.${RESET}"
    exit 1
fi

# ログの記録
log_message() {
    local MESSAGE=$1
    echo "$(date): ${MESSAGE}" >> "$LOG_FILE"
}

log_message "SSL certificates update and container restart script started."

# 証明書と鍵のエンコード
log_message "Certificate and key encoding start..."
bash "${SCRIPT_DIR}/encode-certs.sh"

# Nginxコンテナのリロード
log_message "Reloading Nginx container with new certificates..."
bash "${SCRIPT_DIR}/update-container-nginx-cert.sh"

# ログの記録
log_message "SSL certificates updated and containers restarted."

echo -e "${BRIGHT_GREEN}Script execution completed successfully.${RESET}"
