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
ENV_FILE="$SCRIPT_DIR/env/.env.initialization"

# .env.initializationファイルを読み込む
if [ -f "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
else
    echo -e "${BRIGHT_RED}${ENV_FILE} file not found.${RESET}"
    exit 1
fi

echo -e "${BRIGHT_BLUE}Initialization Start.${RESET}"

# ログディレクトリの作成
if [ -z "$LOG_DIR" ]; then
    echo -e "${BRIGHT_RED}LOG_DIR is not set. Exiting.${RESET}"
    exit 1
fi

if [ ! -d "$LOG_DIR" ]; then
    echo -e "${BRIGHT_BLUE}Creating log directory...${RESET}"
    mkdir -p "$LOG_DIR"
else
    echo -e "${BRIGHT_YELLOW}Log directory already exists. Skipping creation.${RESET}"
fi

# Dockerのインストール確認
if ! command -v docker &> /dev/null; then
    echo -e "${BRIGHT_YELLOW}Docker is not installed. Skipping Docker-related steps.${RESET}"
else
    # Docker composeファイルの存在確認
    if [ -f "$SCRIPT_DIR/docker-compose.yaml" ]; then
        echo -e "${BRIGHT_BLUE}Stopping Docker containers and pruning the system...${RESET}"
        docker compose -f "$SCRIPT_DIR/docker-compose.yaml" stop

        echo -e "${BRIGHT_BLUE}Pruning Docker system...${RESET}"
        docker system prune -af
    else
        echo -e "${BRIGHT_YELLOW}Docker compose file not found. Skipping Docker-related steps.${RESET}"
    fi
fi

# Nginxのキャッシュディレクトリの存在確認
if [ -z "$NGINX_CACHE" ]; then
    echo -e "${BRIGHT_RED}NGINX_CACHE is not set. Skipping Nginx cache clearing.${RESET}"
else
    if [ -d "$NGINX_CACHE" ]; then
        echo -e "${BRIGHT_BLUE}Clearing Nginx cache...${RESET}"
        rm -rf "$NGINX_CACHE"/*
    else
        echo -e "${BRIGHT_YELLOW}Nginx cache directory not found. Skipping Nginx cache clearing.${RESET}"
    fi
fi

echo -e "${BRIGHT_GREEN}Initialization Successfully.${RESET}"
