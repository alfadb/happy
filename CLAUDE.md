# CLAUDE.md

本文件为 Claude Code (claude.ai/code) 在此仓库中工作时提供指引。

## 项目简介

Happy 是团队内部开发辅助工具，用于随时随地操控 AI 编码 CLI 工具（Claude Code、Codex 等）。这不是对外发布的产品，决策时优先考虑团队实际使用效率。

技术上，Happy 是支持端到端加密的移动端/Web 客户端，开发者可通过手机/平板远程控制 AI 编程代理。系统采用 Yarn monorepo，包含四个核心包。

## Monorepo 结构

| 包 | 用途 | 入口 |
|---|------|------|
| `happy-cli` | 全局安装的 CLI 封装（命令名 `happy`） | `src/index.ts` → `bin/happy.mjs` |
| `happy-app` | React Native (Expo) 移动端 + Web + Tauri 桌面端 | `sources/app/`（文件路由） |
| `happy-server` | Fastify 后端 + Prisma ORM | `sources/main.ts` |
| `happy-agent` | 远程代理控制 CLI | `src/index.ts` |
| `happy-wire` | 所有包共享的 Zod schema | `src/` |

每个包有独立的 `CLAUDE.md`，包含包级别的具体规范——在该包中工作前务必先阅读。

## 命令

### Monorepo 级别
```bash
yarn install                        # 安装所有依赖
yarn cli                            # 开发模式运行 happy-cli
yarn workspace happy build          # 构建指定包
yarn workspace happy test           # 测试指定包
```

### happy-cli (`packages/happy-cli/`)
```bash
yarn build          # 编译（tsc + pkgroll）
yarn test           # 构建 + vitest
yarn dev            # tsx 开发模式
yarn typecheck      # TypeScript 类型检查
```

### happy-app (`packages/happy-app/`)
```bash
yarn start          # Expo 开发服务器
yarn web            # 浏览器运行
yarn ios            # iOS 模拟器
yarn android        # Android 模拟器
yarn tauri:dev      # macOS 桌面端（Tauri，热重载）
yarn typecheck      # TypeScript 类型检查（每次改动后必须运行）
```

### happy-server (`packages/happy-server/`)
```bash
yarn standalone:dev # PGlite 本地开发——无需 Docker（推荐）
yarn dev            # 完整开发环境（需外部 Postgres + Redis）
yarn test           # 运行 vitest
yarn generate       # 生成 Prisma client（禁止手动创建 migration）
```

### happy-agent (`packages/happy-agent/`)
```bash
yarn build          # 编译到 dist/
yarn test           # 构建 + vitest
yarn dev            # tsx 开发模式
```

### 运行单个测试
```bash
cd packages/<package>
yarn vitest run path/to/file.test.ts
```

## 架构

### 通信流程
```
移动端/Web 应用 ←→ WebSocket (Socket.IO) ←→ Happy Server ←→ PostgreSQL + Redis
                                                ↕
                                           Happy CLI/Agent（开发者机器上）
```

### 关键架构决策
- **端到端加密**：所有数据在离开设备前使用 TweetNaCl/libsodium 加密。Base64 编解码必须使用 `privacyKit.encodeBase64`/`decodeBase64`（来自 privacy-kit），禁止直接使用 Buffer。
- **双模 Claude 集成**：基于 PTY 的交互模式（已废弃路径）和基于 SDK 的远程模式（`@anthropic-ai/claude-code`）。
- **守护进程架构**：`happy daemon start` 启动后台服务管理多个会话，支持从移动端远程创建会话。
- **会话持久化**：会话在守护进程重启后仍可恢复，状态文件存储在 `~/.happy-dev/`。
- **实时同步**：基于 WebSocket 的乐观并发控制，同步引擎位于 `happy-app/sources/sync/`。
- **独立开发模式**：Server 内嵌 PGlite（进程内 Postgres），本地开发零外部依赖。
- **多 AI 支持**：通过子命令支持 Claude、Codex (Google)、Gemini 和通用 ACP 代理。

### Wire 协议
`happy-wire` 定义所有共享 Zod schema。此处的改动影响所有包——视为契约边界。

## 代码规范（全包适用）

- **4 空格**缩进，不是 2
- 包管理使用 **Yarn**，禁止 npm
- 全面启用 **TypeScript strict mode**
- 通过 `@/` 路径别名使用**绝对导入**（映射到 `src/` 或 `sources/`）
- **函数式风格**——避免使用类（`AsyncLock`、`SyncSocket` 等合理场景除外）
- **禁止 enum**——用 map 替代
- **优先使用 interface** 而非 type alias
- 优先使用**命名导出**
- **所有 import 必须在文件顶部**——禁止在代码中间导入
- 系统边界处使用 **Zod** 做运行时校验
- 测试使用 **Vitest**，不做 mock——测试直接发起真实调用
- **测试文件命名**：`.test.ts`（cli、agent）或 `.spec.ts`（server）

## 环境变量

| 变量 | 所属包 | 用途 |
|------|--------|------|
| `HAPPY_SERVER_URL` | cli | 自定义服务器地址 |
| `HAPPY_HOME_DIR` | cli | 数据目录（默认 `~/.happy-dev`） |
| `HANDY_MASTER_SECRET` | server | 认证主密钥 |
| `PORT` | server | 服务端口（默认 3005） |
| `DATABASE_URL` | server | Postgres 连接串（仅生产环境） |
| `REDIS_URL` | server | Redis 连接串（仅生产环境） |

## 调试

- **CLI 守护进程日志**：`~/.happy-dev/logs/YYYY-MM-DD-HH-MM-SS-daemon.log`
- **Server 日志**：`packages/happy-server/.logs/MM-DD-HH-MM-SS.log`
- **启用远程日志**：设置 `DANGEROUSLY_LOG_TO_SERVER_FOR_AI_AUTO_DEBUGGING=true`
- **CLI 日志规则**：所有调试输出写入文件日志，避免干扰 Claude 终端 UI——禁止使用 console.log 调试

## CI/CD

- `.github/workflows/typecheck.yml` — `happy-app` 变更时的 TypeScript 检查
- `.github/workflows/cli-smoke-test.yml` — CLI 二进制文件测试，覆盖 Node 20+24、Linux + Windows（测试 `happy --help`、`--version`、`doctor`、`daemon status`）
