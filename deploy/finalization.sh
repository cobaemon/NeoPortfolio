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
ENV_FILE="$SCRIPT_DIR/env/.env.finalization"

# .env.finalizationファイルを読み込む
if [ -f "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
else
    echo -e "${BRIGHT_RED}${ENV_FILE} file not found.${RESET}"
    exit 1
fi


# Nginxの設定ファイルをコピー
echo -e "${BRIGHT_BLUE}Copying Nginx configuration files...${RESET}"
cp -f "$SCRIPT_DIR/conf/host_nginx.conf" /etc/nginx/nginx.conf
cp -f "$SCRIPT_DIR/conf/host_portfolio.conf" /etc/nginx/conf.d/host_portfolio.conf

# Nginxの再起動
echo -e "${BRIGHT_BLUE}Restarting Nginx...${RESET}"
systemctl restart nginx

# docker composeの実行
echo -e "${BRIGHT_BLUE}docker compose build and up...${RESET}"
docker compose -f deploy/docker-compose.yaml build --no-cache
docker compose -f deploy/docker-compose.yaml up -d

# Cronjobでパブリックアドレスの変更を自動でドメインに反映
echo -e "${BRIGHT_BLUE}Setting up cron job for updating Route 53 record...${RESET}"
CRON_JOB="0 * * * * ${SCRIPT_DIR}/update-route53-record.sh >> ${LOG_DIR}/update-route53-record.log 2>&1"
(crontab -l 2>/dev/null | grep -F "$CRON_JOB" || (crontab -l 2>/dev/null; echo "$CRON_JOB")) | crontab -

echo -e "${BRIGHT_GREEN}Finalize completed successfully.${RESET}"
