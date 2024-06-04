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
ENCODE_CERTS_ENV_FILE="$SCRIPT_DIR/.env.encode-certs"

echo -e "${BRIGHT_BLUE}Certificate and key encoding start.${RESET}"

# .env.certファイルの存在確認
if [ -f "$CERTS_ENV_FILE" ]; then
    set -a
    source "$CERTS_ENV_FILE"
    set +a
else
    echo -e "${BRIGHT_RED}${CERTS_ENV_FILE} file not found.${RESET}"
    exit 1
fi

# .env.encode-certsファイルの存在確認
if [ -f "$ENCODE_CERTS_ENV_FILE" ]; then
    set -a
    source "$ENCODE_CERTS_ENV_FILE"
    set +a
else
    echo -e "${BRIGHT_RED}${ENCODE_CERTS_ENV_FILE} file not found.${RESET}"
    exit 1
fi

# Base64エンコード
echo -e "${BRIGHT_YELLOW}Encoding certificate and key...${RESET}"
if [ -f "$CERT_PATH" ]; then
    ENCODED_CERT=$(base64 -w 0 "$CERT_PATH")
else
    echo -e "${BRIGHT_RED}Certificate file not found at $CERT_PATH. Exiting.${RESET}"
    exit 1
fi

if [ -f "$KEY_PATH" ]; then
    ENCODED_KEY=$(base64 -w 0 "$KEY_PATH")
else
    echo -e "${BRIGHT_RED}Key file not found at $KEY_PATH. Exiting.${RESET}"
    exit 1
fi

# .envファイルの特定の行を更新
echo -e "${BRIGHT_YELLOW}Updating .env file with encoded certificate and key...${RESET}"
sed -i "s|^SSL_CERTIFICATE=.*$|SSL_CERTIFICATE=$ENCODED_CERT|" "$CERTS_ENV_FILE"
sed -i "s|^SSL_CERTIFICATE_KEY=.*$|SSL_CERTIFICATE_KEY=$ENCODED_KEY|" "$CERTS_ENV_FILE"

echo -e "${BRIGHT_GREEN}Certificate and key encoding successfully.${RESET}"
