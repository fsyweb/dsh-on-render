# =============================================================================
# dsh 云端工作台 — Zeabur Free Plan (Docker)
# 架构: 公网 *.zeabur.app -> Caddy(:$PORT + Basic Auth + WS透传) -> dsh 127.0.0.1:3080
# 不改 dsh 源码；dsh 仅绑回环，靠 Caddy 对外 + 鉴权
# Zeabur 会注入 $PORT 环境变量(通常 8080)，Caddy 监听它
# =============================================================================

# 多阶段：从官方 caddy 镜像拷贝静态二进制，免手动下载版本
FROM caddy:2 AS caddy-bin

FROM node:24-slim

# 拷贝 caddy 二进制
COPY --from=caddy-bin /usr/bin/caddy /usr/bin/caddy

# 系统依赖：curl(健康探活) git(工作区同步) ca-certificates
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates git \
    && rm -rf /var/lib/apt/lists/*

# 全局安装 dsh (官方 npm 包，预构建产物，不改源码)
RUN npm install -g @deepseek-ai/dsh && dsh --version

# 非 root 运行 (uid 1000，Zeabur 也以非 root 跑容器)
RUN useradd -m -u 1000 dsh-user

WORKDIR /home/dsh-user/app
COPY --chown=dsh-user:dsh-user scripts/ ./scripts/
RUN chmod +x ./scripts/*.sh

# dsh 工作区 (Agent 在这里读写文件)
RUN mkdir -p /home/dsh-user/workspace /home/dsh-user/.dsh \
    && chown -R dsh-user:dsh-user /home/dsh-user

ENV HOME=/home/dsh-user \
    DSH_HOST=127.0.0.1 \
    DSH_PORT=3080 \
    DSH_BASICAUTH_USER=admin \
    PORT=8080

# Caddy 实际监听 $PORT(Zeabur 注入)，EXPOSE 仅声明默认值
EXPOSE 8080

USER dsh-user
CMD ["./scripts/start.sh"]
