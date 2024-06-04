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
ENV_FILE="$SCRIPT_DIR/env/.env.openssl-setup"

echo -e "${BRIGHT_BLUE}Openssl Setup Start.${RESET}"

# 環境変数ファイルの読み込み
if [ -f "$ENV_FILE" ]; then
    echo -e "${BRIGHT_YELLOW}Loading environment variables from ${ENV_FILE}...${RESET}"
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

# 必要なパッケージのインストール
echo -e "${BRIGHT_BLUE}Installing dependencies...${RESET}"
if [ "$OS" = "ubuntu" ]; then
    $PKG_MANAGER install -y build-essential checkinstall zlib1g-dev
elif [ "$OS" = "centos" ]; then
    $PKG_MANAGER groupinstall -y "Development Tools"
    $PKG_MANAGER install -y gcc perl-core make
fi

# OpenSSLのダウンロードとインストール
OPENSSL_DIR="/usr/local/src/openssl-$OPENSSL_VERSION"
if [ ! -d "$OPENSSL_DIR" ]; then
    echo -e "${BRIGHT_YELLOW}Downloading OpenSSL $OPENSSL_VERSION...${RESET}"
    cd /usr/local/src
    wget https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz
    tar -zxf openssl-$OPENSSL_VERSION.tar.gz
    cd openssl-$OPENSSL_VERSION

    echo -e "${BRIGHT_YELLOW}Installing OpenSSL $OPENSSL_VERSION...${RESET}"
    ./config --prefix=/usr/local/openssl --openssldir=/usr/local/openssl
    make
    make install

    echo -e "${BRIGHT_YELLOW}Updating symbolic links...${RESET}"
    mv /usr/bin/openssl /usr/bin/openssl.bak || true
    ln -s /usr/local/openssl/bin/openssl /usr/bin/openssl

    echo -e "${BRIGHT_YELLOW}Updating library path...${RESET}"
    echo "/usr/local/openssl/lib" | tee -a /etc/ld.so.conf.d/openssl-$OPENSSL_VERSION.conf
    ldconfig
else
    echo -e "${BRIGHT_YELLOW}OpenSSL $OPENSSL_VERSION is already installed.${RESET}"
fi

# インストールの確認
openssl version

echo -e "${BRIGHT_GREEN}Openssl Setup Successfully.${RESET}"
