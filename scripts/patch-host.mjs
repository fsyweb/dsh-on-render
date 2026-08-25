#!/usr/bin/env node
// =============================================================================
// 备选补丁: 解除 dsh CLI 对 --host 0.0.0.0 的拦截。
//
// 何时用:
//   - 主路径(Caddy 反代)不需要这个 —— dsh 保持绑 127.0.0.1 即可。
//   - 仅当你想跳过 Caddy、让 dsh 直接绑 0.0.0.0 暴露(并自行加防护)时才用。
//
// 用法: 在 deepseek-harness 源码仓库根目录执行
//   node scripts/patch-host.mjs
// 改完重新 `pnpm run build`，产物即支持 --host 0.0.0.0。
//
// 这是对源码的最小改动(删 3 行 if 块)，符合"不大动工、脚本改造"。
// =============================================================================
import { readFileSync, writeFileSync } from 'node:fs'

const file = 'packages/bundle/web-app/src/startup.ts'

const needle =
  "    if (options.host === '0.0.0.0') {\n" +
  "      program.error('error: --host 0.0.0.0 is intentionally not supported yet for safety: it would expose remote code execution to the network; use 127.0.0.1 instead')\n" +
  "    }\n"

let src
try {
  src = readFileSync(file, 'utf8')
} catch (e) {
  console.error(`找不到 ${file}，请在 deepseek-harness 源码仓库根目录运行此脚本。`)
  process.exit(1)
}

if (!src.includes(needle)) {
  // 可能已打补丁，或上游代码变了
  if (src.includes('0.0.0.0')) {
    console.warn(`[patch] ${file} 中仍含 0.0.0.0 字样但未匹配目标块，可能上游代码已变更，需人工检查。`)
  } else {
    console.log(`[patch] ${file} 已无 0.0.0.0 拦截，可能已打过补丁。`)
  }
  process.exit(0)
}

src = src.replace(needle, '')
writeFileSync(file, src)
console.log(`[patch] 已解除 --host 0.0.0.0 限制: ${file}`)
console.log('[patch] 接下来执行: pnpm run build  (产物即支持 0.0.0.0)')
