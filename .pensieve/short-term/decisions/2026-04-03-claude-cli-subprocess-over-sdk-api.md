---
id: claude-cli-subprocess-over-sdk-api
type: decision
title: 通过子进程调用 Claude CLI 而非直接使用 SDK API
status: active
created: 2026-04-03
updated: 2026-04-03
tags: [claude, architecture, decision]
---

# 通过子进程调用 Claude CLI 而非直接使用 SDK API

## 一句话结论
> Happy 将 Claude CLI 作为子进程启动并通过 JSON 流通信，而非直接调用 `@anthropic-ai/claude-code` 的 programmatic API。

## 上下文链接
- 基于：[[knowledge/claude-integration-architecture/content]]
- 导致：none
- 相关：none

## Context
Happy 需要集成 Claude Code 来执行编程任务。Claude Code 同时提供 CLI 二进制和 `@anthropic-ai/claude-code` npm 包的 programmatic API。

## Problem
如何在 Happy CLI 中集成 Claude Code，同时支持本地交互和远程移动端控制两种模式。

## Alternatives Considered
- **直接使用 SDK programmatic API**：更紧密耦合，但需要自行处理所有 Claude Code 内部逻辑（工具执行、文件 I/O、上下文管理等）
- **子进程 + JSON 流**（当前选择）：通过 `--output-format stream-json` 获取结构化输出，通过 `--permission-prompt-tool stdio` 控制权限流，复用 Claude CLI 全部内置能力

## Decision
选择子进程方式，因为：
1. 复用 Claude CLI 的全部功能（工具、MCP、权限系统），无需重新实现
2. `--input-format stream-json` 天然支持远程消息注入
3. 版本解耦——Claude CLI 升级不需要 Happy 改代码
4. 支持多种安装来源（npm、Homebrew、原生安装器）

## Consequence
- 依赖 Claude CLI 的 stream-json 输出格式稳定性
- 进程管理复杂度增加（生命周期、信号处理、abort controller）
- launcher 脚本层（`claude_local_launcher.cjs`、`claude_remote_launcher.cjs`）增加了间接性

## 探索减负
- 下次可以少问什么：Happy 如何调用 Claude → 子进程 spawn，不是 SDK import
- 下次可以少查什么：消息流方向 → stdout 读、stdin 写，参考 `query.ts`
- 失效条件：如果 Claude Code 弃用 `stream-json` 输出格式或 `--permission-prompt-tool stdio`
