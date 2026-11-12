#!/usr/bin/env bash
# PC-Free 一键启动: 体检 + 准备 + 启动 Windows 10 (dockurr/windows)
# 用法: bash go.sh
set -u
cd "$(dirname "$0")"

echo "========== 1/4 体检 =========="
echo "--- 磁盘 ---"; df -h / /tmp /workspaces 2>/dev/null | sort -u
echo "--- CPU/内存 ---"; echo "CPU 核数: $(nproc)"; free -h | head -2
echo "--- KVM ---"
if [ -e /dev/kvm ]; then ls -l /dev/kvm; else echo "!! 没有 /dev/kvm: Windows 只能纯软件模拟, 会非常慢或起不来"; fi
echo "--- Docker ---"; docker --version || { echo "!! Docker 没装好, 停"; exit 1; }
docker info >/dev/null 2>&1 || { echo "!! Docker 守护进程没在跑, 停"; exit 1; }
echo "Docker Root Dir: $(docker info 2>/dev/null | grep 'Docker Root Dir')"

echo "========== 2/4 准备目录与账号 =========="
sudo mkdir -p /tmp/docker-data/windows 2>/dev/null || mkdir -p /tmp/docker-data/windows
if [ ! -f .env ]; then
  printf 'WINDOWS_USERNAME=kao\nWINDOWS_PASSWORD=Kao123456\n' > .env
  echo "已生成 .env: Windows 用户名 kao / 密码 Kao123456 (进系统后请到设置里改掉)"
else
  echo ".env 已存在, 沿用里面的账号密码"
fi

echo "========== 3/4 启动 Windows =========="
if docker compose version >/dev/null 2>&1; then
  docker compose -f windows10.yml up -d
elif command -v docker-compose >/dev/null 2>&1; then
  docker-compose -f windows10.yml up -d
else
  echo "!! 找不到 docker compose, 停"; exit 1
fi

echo "========== 4/4 当前状态 =========="
sleep 5
docker ps --filter name=windows
echo "--- 最近日志 ---"
docker logs --tail 30 windows 2>&1 || true
echo ""
echo "接下来: 打开下方 Ports(端口) 页签 -> 找到 8006 -> 保持 Private -> 点地球图标打开 = Windows 桌面"
echo "第一次安装要下载约 5-6GB 并自动装系统, 约 15-40 分钟; 看进度重复运行: docker logs -f windows"
