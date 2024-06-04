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
ENV_FILE="$SCRIPT_DIR/env/.env.update-route53-record"
CERTBOT_ENV_FILE="$SCRIPT_DIR/env/.env.certbot-setup"

# .env.update-route53-recordファイルの読み込み
if [ -f "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
else
    echo -e "${BRIGHT_RED}${ENV_FILE} file not found.${RESET}"
    exit 1
fi

# .env.certbot-setupファイルの読み込み
if [ -f "$CERTBOT_ENV_FILE" ]; then
    set -a
    source "$CERTBOT_ENV_FILE"
    set +a
else
    echo -e "${BRIGHT_RED}${CERTBOT_ENV_FILE} file not found.${RESET}"
    exit 1
fi

# AWS CLIプロファイルの設定
AWS_CREDENTIALS_FILE="$HOME/.aws/credentials"
AWS_CONFIG_FILE="$HOME/.aws/config"

# AWSプロファイルの設定を確認して更新
if ! grep -q "^\[$AWS_PROFILE\]" "$AWS_CREDENTIALS_FILE" 2>/dev/null; then
    echo -e "${BRIGHT_BLUE}Creating AWS CLI credentials profile: $AWS_PROFILE${RESET}"
    mkdir -p ~/.aws
    cat >> "$AWS_CREDENTIALS_FILE" <<EOL
[$AWS_PROFILE]
aws_access_key_id = $AWS_ACCESS_KEY_ID
aws_secret_access_key = $AWS_SECRET_ACCESS_KEY
EOL
else
    echo -e "${BRIGHT_BLUE}AWS CLI credentials profile $AWS_PROFILE already exists.${RESET}"
fi

if ! grep -q "^\[profile $AWS_PROFILE\]" "$AWS_CONFIG_FILE" 2>/dev/null; then
    echo -e "${BRIGHT_BLUE}Creating AWS CLI config profile: $AWS_PROFILE${RESET}"
    mkdir -p ~/.aws
    cat >> "$AWS_CONFIG_FILE" <<EOL
[profile $AWS_PROFILE]
region = $AWS_DEFAULT_REGION
EOL
else
    echo -e "${BRIGHT_BLUE}AWS CLI config profile $AWS_PROFILE already exists.${RESET}"
fi

# 現在のパブリックIPアドレスを取得
echo -e "${BRIGHT_BLUE}Fetching current public IP address...${RESET}"
PUBLIC_IP=$(curl -s https://api.ipify.org)

# 現在のRoute 53のAレコードを取得
echo -e "${BRIGHT_BLUE}Fetching current A record for $DOMAIN_NAME from Route 53...${RESET}"
CURRENT_IP=$(aws route53 list-resource-record-sets \
    --hosted-zone-id $HOSTED_ZONE_ID \
    --query "ResourceRecordSets[?Name == '${DOMAIN_NAME}.'].ResourceRecords[0].Value" \
    --output text \
    --profile $AWS_PROFILE)

# IPアドレスが異なる場合のみ更新
echo -e "${BRIGHT_BLUE}$(date '+%Y/%m/%d/%H/%M/%S')${RESET}"
if [ "$PUBLIC_IP" != "$CURRENT_IP" ]; then
    echo -e "${BRIGHT_GREEN}Public IP has changed. Updating Route 53 A record...${RESET}"
    CHANGE_BATCH=$(cat <<EOF
{
    "Comment": "Auto updating public IP",
    "Changes": [{
        "Action": "UPSERT",
        "ResourceRecordSet": {
            "Name": "$DOMAIN_NAME",
            "Type": "A",
            "TTL": 3600,
            "ResourceRecords": [{"Value": "$PUBLIC_IP"}]
        }
    }]
}
EOF
)
    aws route53 change-resource-record-sets \
        --hosted-zone-id $HOSTED_ZONE_ID \
        --change-batch "$CHANGE_BATCH" \
        --profile $AWS_PROFILE

    echo -e "${BRIGHT_GREEN}Updated A record from $CURRENT_IP to $PUBLIC_IP${RESET}"
else
    echo -e "${BRIGHT_YELLOW}No change in IP address${RESET}"
fi
