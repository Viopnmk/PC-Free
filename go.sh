#!/usr/bin/env bash
# PC-Free 一键启动 v2: 体检 + (缺了就自装 Docker) + 按机器大小调参 + 启动 Windows 10
# 用法: bash go.sh
set -u
cd "$(dirname "$0")"

echo "========== 1/5 体检 =========="
echo "--- 磁盘 ---"; df -h / /tmp /workspaces 2>/dev/null | sort -u
CORES=$(nproc); MEMG=$(free -g | awk '/^Mem:/{print $2}')
echo "--- CPU/内存 ---"; echo "CPU 核数: $CORES, 内存: ${MEMG}G"
echo "--- KVM ---"
if [ -e /dev/kvm ]; then ls -l /dev/kvm; else echo "!! 没有 /dev/kvm: Windows 只能纯软件模拟, 会非常慢或起不来"; fi

echo "========== 2/5 Docker =========="
if grep -qi alpine /etc/os-release 2>/dev/null; then
  echo "!! 当前是 Alpine 恢复容器: 说明这台 Codespace 的 devcontainer 构建失败了, 在这里装不了 Docker"
  echo "!! 处理: 删掉这台 Codespace 重新建一台 (新配置已修好), 不要在这里继续重试"
  exit 1
fi
if ! command -v docker >/dev/null 2>&1; then
  echo "Docker 没装, 现在用官方脚本自装 (约 1-2 分钟)..."
  curl -fsSL https://get.docker.com -o /tmp/get-docker.sh && sudo sh /tmp/get-docker.sh || { echo "!! Docker 安装失败, 把这屏截图给烤冷面"; exit 1; }
fi
docker --version
if ! docker info >/dev/null 2>&1; then
  echo "Docker 守护进程没在跑, 尝试拉起..."
  (sudo nohup dockerd > /tmp/dockerd.log 2>&1 &)
  for i in $(seq 1 20); do sleep 2; docker info >/dev/null 2>&1 && break; done
fi
docker info >/dev/null 2>&1 || { echo "!! Docker 守护进程起不来, 看 /tmp/dockerd.log; 把这屏截图给烤冷面"; exit 1; }
echo "Docker 就绪. Root Dir: $(docker info 2>/dev/null | grep 'Docker Root Dir' | awk '{print $4}')"

echo "========== 3/5 准备目录与账号 + 按机器调参 =========="
sudo mkdir -p /tmp/docker-data/windows 2>/dev/null || mkdir -p /tmp/docker-data/windows
if [ ! -f .env ]; then
  printf 'WINDOWS_USERNAME=kao\nWINDOWS_PASSWORD=Kao123456\n' > .env
  echo "已生成 .env: Windows 用户名 kao / 密码 Kao123456 (进系统后请到设置里改掉)"
else
  echo ".env 已存在, 沿用里面的账号密码"
fi
if [ "$CORES" -ge 4 ] && [ "$MEMG" -ge 14 ]; then
  export RAM_SIZE=8G CPU_CORES=4
else
  export RAM_SIZE=4G CPU_CORES=2
fi
echo "本机规格 -> Windows 分配: RAM $RAM_SIZE, CPU $CPU_CORES 核"

echo "========== 4/5 启动 Windows =========="
if docker compose version >/dev/null 2>&1; then
  docker compose -f windows10.yml up -d
elif command -v docker-compose >/dev/null 2>&1; then
  docker-compose -f windows10.yml up -d
else
  echo "!! 找不到 docker compose, 把这屏截图给烤冷面"; exit 1
fi

echo "========== 5/5 当前状态 =========="
sleep 5
docker ps --filter name=windows
echo "--- 最近日志 ---"
docker logs --tail 30 windows 2>&1 || true
echo ""
echo "接下来: 打开下方 Ports(端口) 页签 -> 找到 8006 -> 保持 Private -> 点地球图标打开 = Windows 桌面"
echo "第一次安装要下载约 5-6GB 并自动装系统, 约 15-40 分钟; 看进度手打: docker logs -f windows (Ctrl+C 退出看日志)"
