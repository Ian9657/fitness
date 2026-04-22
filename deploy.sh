#!/bin/bash
# ========================================
# 一键部署训练计划到 VPS
# 用法: bash deploy.sh <VPS_IP>
# 例如: bash deploy.sh 149.28.xx.xx
# ========================================

set -e

VPS_IP="${1:?用法: bash deploy.sh <VPS_IP>}"
VPS_USER="root"
REMOTE_DIR="/var/www/fitness"
LOCAL_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "🚀 正在部署到 ${VPS_IP}..."

# 1. 在 VPS 上安装 nginx（如果没装的话）并创建目录
ssh ${VPS_USER}@${VPS_IP} << 'SETUP'
if ! command -v nginx &> /dev/null; then
  echo "📦 安装 nginx..."
  apt update -qq && apt install -y nginx
fi
mkdir -p /var/www/fitness
SETUP

# 2. 上传文件
echo "📤 上传文件..."
scp "${LOCAL_DIR}/index.html" ${VPS_USER}@${VPS_IP}:${REMOTE_DIR}/
scp "${LOCAL_DIR}/manifest.json" ${VPS_USER}@${VPS_IP}:${REMOTE_DIR}/ 2>/dev/null || true
scp "${LOCAL_DIR}/sw.js" ${VPS_USER}@${VPS_IP}:${REMOTE_DIR}/ 2>/dev/null || true
scp "${LOCAL_DIR}/icon-192.png" ${VPS_USER}@${VPS_IP}:${REMOTE_DIR}/ 2>/dev/null || true
scp "${LOCAL_DIR}/icon-512.png" ${VPS_USER}@${VPS_IP}:${REMOTE_DIR}/ 2>/dev/null || true

# 3. 写入 nginx 配置
ssh ${VPS_USER}@${VPS_IP} << 'NGINX'
cat > /etc/nginx/sites-available/fitness << 'EOF'
server {
    listen 80;
    listen [::]:80;
    server_name _;

    root /var/www/fitness;
    index index.html;

    # 安全头
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    # gzip 压缩
    gzip on;
    gzip_types text/html text/css application/javascript application/json;
    gzip_min_length 1000;

    # 静态资源缓存
    location ~* \.(js|json|png|ico|webp)$ {
        expires 7d;
        add_header Cache-Control "public, immutable";
    }

    # PWA service worker 不缓存
    location = /sw.js {
        expires -1;
        add_header Cache-Control "no-store, no-cache, must-revalidate";
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
EOF

# 启用站点
ln -sf /etc/nginx/sites-available/fitness /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# 测试 & 重启
nginx -t && systemctl restart nginx
NGINX

echo ""
echo "✅ 部署完成！"
echo "🌐 访问: http://${VPS_IP}"
echo ""
echo "📱 手机上用 Safari 打开上面的地址，然后:"
echo "   点「分享」→「添加到主屏幕」→ 就像原生 App 一样使用"
echo ""
echo "🔒 如果要加 HTTPS + 域名，运行:"
echo "   ssh root@${VPS_IP}"
echo "   apt install -y certbot python3-certbot-nginx"
echo "   certbot --nginx -d 你的域名.com"
