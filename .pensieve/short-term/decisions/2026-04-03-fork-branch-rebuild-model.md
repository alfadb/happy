---
id: fork-branch-rebuild-model
type: decision
title: Fork 集成分支采用重建模型而非 rebase
status: active
created: 2026-04-03
updated: 2026-04-03
tags: [git, fork, branch-management, workflow]
---

# Fork 集成分支采用重建模型而非 rebase

## 一句话结论
> integrate 分支不做增量 rebase，而是通过脚本从 main 重建：依次 cherry-pick pr/* 和 private/* 分支。

## 上下文链接
- 基于：[[decisions/2026-04-03-claude-cli-subprocess-over-sdk-api]]
- 导致：none
- 相关：none

## Context
仓库是 slopus/happy 的 fork，需要同时管理：向上游提交的 PR 分支、私有功能/配置分支、工具数据分支（CLAUDE.md、.pensieve/）。集成分支需要包含所有这些改动，并定期同步上游。

## Problem
集成分支有多个来源的提交（PR、私有功能、工具数据），直接 rebase 时冲突来源不明、解决后状态不可预测。

## Alternatives Considered
- **增量 rebase**：`git rebase upstream/main integrate` — 多来源提交混在一起，冲突时无法判断是哪个功能分支引起的
- **merge 方式**：各分支 merge 进 integrate — 产生大量 merge commit，历史混乱
- **重建模型**（当前选择）：每次从 main 重新 cherry-pick — 冲突可精确定位到具体分支

## Decision

分支分层：
```
main (= upstream/main) → pr/* (先) → private/* (后) = integrate
```

集成顺序：PR 分支先入（干净改动，冲突少），private 分支后叠。PR 被上游合并后从列表删除，改动自然通过 main 进入。

所有私有工具（脚本、CLAUDE.md、.pensieve/）放在 `private/tooling` 分支。

重建脚本：`scripts/rebuild-integrate.sh`，支持 `--dry-run`。

integrate 是 force-push 分支——每次重建后需 `git push --force-with-lease origin integrate`。

## Consequence
- 每次重建是全量 cherry-pick，分支多时耗时增加（但当前规模可忽略）
- 需要维护脚本顶部的分支列表
- 团队成员不应基于 integrate 分支开发（历史会被重写）

## 探索减负
- 下次可以少问什么：integrate 怎么同步上游 → 跑 `bash scripts/rebuild-integrate.sh`
- 下次可以少查什么：私有数据放哪个分支 → `private/tooling`；integrate 的集成顺序 → pr 先 private 后
- 失效条件：如果 private 分支数量超过 ~10 个导致重建耗时过长，需改用增量方案
