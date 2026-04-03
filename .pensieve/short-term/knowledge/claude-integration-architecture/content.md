---
id: claude-integration-architecture
type: knowledge
title: Happy 项目 Claude 集成架构
status: active
created: 2026-04-03
updated: 2026-04-03
tags: [claude, sdk, architecture, integration]
---

# Happy 项目 Claude 集成架构

## Source
- `packages/happy-cli/src/claude/sdk/query.ts` — 进程启动与消息流核心
- `packages/happy-cli/src/claude/claudeLocal.ts` — 本地模式
- `packages/happy-cli/src/claude/claudeRemote.ts` — 远程模式
- `packages/happy-cli/src/claude/loop.ts` — 模式切换主循环
- `packages/happy-cli/scripts/claude_version_utils.cjs` — Claude CLI 发现

## Summary
Happy 不直接调用 `@anthropic-ai/claude-code` 的 SDK API，而是将 Claude CLI 作为子进程启动，通过 stdin/stdout JSON 流通信。理解这一点可以避免误将集成方式当作标准 SDK 调用。

## Content

### 调用方式：子进程 + JSON 流

核心在 `query.ts:346-354`，通过 `child_process.spawn` 启动 Claude CLI：

```
spawn(claudePath, args, { stdio: ['pipe', 'pipe', 'pipe'] })
```

关键参数：
- `--output-format stream-json --verbose` — JSON 行输出
- `--permission-prompt-tool stdio` — 工具权限走 stdin/stdout 控制
- `--system-prompt` / `--append-system-prompt` — 注入自定义系统提示
- `--resume <sessionId>` — 恢复会话
- `--input-format stream-json` — 远程模式下持续接收消息
- `--settings <path>` — 临时 hook 设置文件（用于会话通知）

### 双模式运行

| 模式 | 入口 | 特点 |
|------|------|------|
| Local | `claudeLocal.ts` | 终端交互，通过 launcher 脚本拦截 fetch 追踪 thinking 状态 |
| Remote | `claudeRemote.ts` | 移动端控制，消息经 WebSocket→Server→Claude 流转 |

`loop.ts:47-110` 负责在两种模式间切换——用户按键切回本地，移动端接管切到远程。

### Claude CLI 发现优先级

`scripts/claude_version_utils.cjs:400-488`：
1. `HAPPY_CLAUDE_PATH` 环境变量
2. PATH 查找（`which`/`where`）
3. npm 全局安装
4. Bun 安装
5. Homebrew
6. 原生安装器

### 权限控制流

1. Claude 发出工具权限请求 → `query.ts:175-207` 捕获
2. 调用 `canCallTool` 回调 → `permissionHandler.ts`
3. 远程模式下转发到移动端等待用户审批
4. 审批结果写回 stdin → Claude 继续/中止

### 会话管理

- 会话通过临时 hook 设置文件（`generateHookSettings.ts`）的 SessionStart hook 回调 Happy
- Hook 服务器 (`startHookServer.ts`) 收到 `claudeSessionId` 后更新会话元数据
- `--resume` 创建新会话文件但携带完整历史，所有历史消息的 sessionId 被重写为新 ID

### OAuth 认证

`authenticateClaude.ts` 实现 Anthropic OAuth PKCE 流程：
- 授权端点：`https://claude.ai/oauth/authorize`
- Token 端点：`https://console.anthropic.com/v1/oauth/token`
- Scope：`user:inference`

## When to Use
- 修改 Claude 集成代码前，先理解消息流方向
- 调试会话创建/恢复问题时，理解 sessionId 重写行为
- 添加新 AI 后端时，参照现有双模式架构
- 排查权限弹窗问题时，追踪 permission-prompt-tool 流程

## 上下文链接
- 基于：[[knowledge/taste-review/content]]
- 导致：none
- 相关：none
