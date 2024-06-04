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
ENV_FILE="$SCRIPT_DIR/env/.env.nginx-setup"

echo -e "${BRIGHT_BLUE}Nginx Setup Start.${RESET}"

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

# 既存のパッケージ版Nginxを削除
if command -v nginx &> /dev/null; then
    echo -e "${BRIGHT_YELLOW}Removing existing package version of Nginx...${RESET}"
    $PKG_MANAGER remove -y nginx
fi

# 必要なパッケージのインストール
echo -e "${BRIGHT_BLUE}Installing dependencies...${RESET}"
if [ "$OS" = "ubuntu" ]; then
    $PKG_MANAGER install -y build-essential checkinstall zlib1g-dev libpcre3 libpcre3-dev unzip
elif [ "$OS" = "centos" ]; then
    $PKG_MANAGER groupinstall -y "Development Tools"
    $PKG_MANAGER install -y pcre pcre-devel zlib zlib-devel make
fi

# Diffie-Hellmanパラメータの生成
if [ ! -f "$DH_PARAM" ]; then
    echo -e "${BRIGHT_YELLOW}Generating Diffie-Hellman parameters...${RESET}"
    openssl dhparam -out $DH_PARAM 2048
else
    echo -e "${BRIGHT_YELLOW}Diffie-Hellman parameters already exist.${RESET}"
fi

# Nginxのソースコードとインストール
NGINX_DIR="/usr/local/src/nginx-$NGINX_VERSION"
if [ ! -d "$NGINX_DIR" ]; then
    echo -e "${BRIGHT_YELLOW}Downloading Nginx $NGINX_VERSION...${RESET}"
    cd /usr/local/src
    wget http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz
    tar -zxvf nginx-$NGINX_VERSION.tar.gz

    echo -e "${BRIGHT_YELLOW}Installing Nginx $NGINX_VERSION...${RESET}"
    cd nginx-$NGINX_VERSION
    ./configure --prefix=/etc/nginx --sbin-path=/usr/sbin/nginx --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --pid-path=/var/run/nginx.pid --lock-path=/var/lock/nginx.lock --with-http_ssl_module --with-http_v2_module --with-openssl=/usr/local/src/openssl-1.1.1k
    make
    make install
else
    echo -e "${BRIGHT_YELLOW}Nginx $NGINX_VERSION is already installed.${RESET}"
fi

# 必要なディレクトリとファイルの作成
echo -e "${BRIGHT_YELLOW}Setting up necessary directories and files...${RESET}"
mkdir -p /etc/nginx/conf.d
mkdir -p /etc/nginx/default.d
mkdir -p /var/log/nginx
mkdir -p /usr/share/nginx/html

# シンボリックリンクの更新
echo 'export PATH=$PATH:/usr/sbin' >> ~/.bashrc
source ~/.bashrc

# systemdユニットファイルの作成
NGINX_SERVICE="/etc/systemd/system/nginx.service"
if [ ! -f "$NGINX_SERVICE" ]; then
    echo -e "${BRIGHT_YELLOW}Creating systemd unit file for Nginx...${RESET}"
    bash -c 'cat << EOF > /etc/systemd/system/nginx.service
[Unit]
Description=A high performance web server and a reverse proxy server
After=network.target

[Service]
Type=forking
PIDFile=/var/run/nginx.pid
ExecStartPre=/usr/sbin/nginx -t
ExecStart=/usr/sbin/nginx
ExecReload=/usr/sbin/nginx -s reload
ExecStop=/bin/kill -s QUIT $MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF'
fi

# systemdデーモンのリロード
systemctl daemon-reload

# Nginxサービスの起動と有効化
systemctl start nginx
systemctl enable nginx

# Nginxの設定ファイルをコピー
echo -e "${BRIGHT_YELLOW}Copying Nginx configuration files...${RESET}"
cp -f "$SCRIPT_DIR/host_nginx.conf" /etc/nginx/nginx.conf
cp -f "$SCRIPT_DIR/host_portfolio.conf" /etc/nginx/conf.d/host_portfolio.conf

# Nginxの設定テストとリロード
echo -e "${BRIGHT_YELLOW}Testing and reloading Nginx...${RESET}"
nginx -t && systemctl reload nginx

echo -e "${BRIGHT_GREEN}Nginx Setup Successfully.${RESET}"
