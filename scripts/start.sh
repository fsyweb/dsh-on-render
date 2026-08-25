#!/usr/bin/env bash
# =============================================================================
# 启动: dsh(回环 3080) + Caddy(0.0.0.0:$PORT + Basic Auth 反代)
# Caddy 透传 WebSocket/SSE；Zeabur 注入 $PORT(通常 8080) 路由公网流量
# =============================================================================
set -euo pipefail

DSH_HOST="${DSH_HOST:-127.0.0.1}"
DSH_PORT="${DSH_PORT:-3080}"
BA_USER="${DSH_BASICAUTH_USER:-admin}"
BA_PASS="${DSH_BASICAUTH_PASS:-}"
# Zeabur 注入 $PORT；本地默认 8080 方便测试
CADDY_PORT="${PORT:-8080}"

if [ -z "$BA_PASS" ]; then
  echo "ERROR: DSH_BASICAUTH_PASS 未设置。请在 Zeabur -> Configuration -> Variables 设置。" >&2
  echo "       这是访问 dsh 的密码(防止公网 RCE)。用户名默认 admin(DSH_BASICAUTH_USER 可改)。" >&2
  exit 1
fi

# 1. 生成 Basic Auth 的 bcrypt hash
echo "[start] 生成 Basic Auth hash ..."
HASH=$(caddy hash-password --plaintext "$BA_PASS")

# 2. 内联生成 Caddyfile (监听 $PORT)
cat > /tmp/Caddyfile <<EOF
:${CADDY_PORT} {
  encode zstd gzip
  basic_auth {
    ${BA_USER} ${HASH}
  }
  reverse_proxy ${DSH_HOST}:${DSH_PORT} {
    # 透传 WebSocket / SSE 长连接
    flush_interval -1
    header_up Host {host}
    header_up X-Real-IP {remote_host}
  }
}
EOF

# 3. 后台启动 dsh (绑回环，不对外)
echo "[start] 启动 dsh on ${DSH_HOST}:${DSH_PORT} ..."
dsh web --host "$DSH_HOST" --port "$DSH_PORT" --no-open &

# 4. 等 dsh 就绪
echo "[start] 等待 dsh 就绪 ..."
for i in $(seq 1 60); do
  if curl -sf -o /dev/null "http://${DSH_HOST}:${DSH_PORT}/" 2>/dev/null; then
    echo "[start] dsh 已就绪 (${i}s)"
    break
  fi
  sleep 1
done

# 5. 前台启动 Caddy (Zeabur 路由命中 $PORT)
echo "[start] 启动 Caddy on :${CADDY_PORT} (Basic Auth: ${BA_USER}) ..."
exec caddy run --config /tmp/Caddyfile --adapter caddyfile
