#!/usr/bin/env bash
# 从 main + pr/* + private/* 分支重建 integrate 集成分支
# 用法: bash scripts/rebuild-integrate.sh [--dry-run]
set -euo pipefail

# ── 配置 ──────────────────────────────────────────
# PR 分支：先集成，上游合并后从列表移除即可
PR_BRANCHES=(
    # pr/fix-xxx
)

# 私有分支：后集成，叠加在 PR 之上
PRIVATE_BRANCHES=(
    private/tooling
    # private/config
    # private/feat-xxx
)

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

# ── 辅助函数 ──────────────────────────────────────
cherry_pick_branch() {
    local branch="$1"
    local base="$2"

    if ! git rev-parse --verify "$branch" &>/dev/null; then
        echo "⚠️  $branch 不存在，跳过"
        return 0
    fi

    local commits
    commits=$(git log "$base".."$branch" --reverse --format=%H)
    if [[ -z "$commits" ]]; then
        echo "⚠️  $branch 无新提交，跳过"
        return 0
    fi

    local count
    count=$(echo "$commits" | wc -l | tr -d ' ')
    echo "→ Cherry-picking $branch ($count commits)..."

    if ! git cherry-pick $commits; then
        echo ""
        echo "❌ 冲突来自 $branch"
        echo "   解决冲突后运行: git cherry-pick --continue"
        echo "   放弃此分支:     git cherry-pick --abort"
        exit 1
    fi
}

print_branch_info() {
    local branch="$1"
    local base="$2"

    if git rev-parse --verify "$branch" &>/dev/null; then
        local count
        count=$(git log "$base".."$branch" --oneline | wc -l | tr -d ' ')
        echo "  $branch ($count commits)"
        git log "$base".."$branch" --oneline | sed 's/^/    /'
    else
        echo "  $branch (不存在，跳过)"
    fi
}

# ── 预检 ──────────────────────────────────────────
if ! git remote get-url upstream &>/dev/null; then
    echo "❌ upstream remote 未配置"
    echo "   运行: git remote add upstream https://github.com/slopus/happy.git"
    exit 1
fi

if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    echo "❌ 工作区有未提交的改动，请先 stash 或提交"
    exit 1
fi

CURRENT_BRANCH=$(git branch --show-current)

# ── 1. 同步上游 ──────────────────────────────────
echo "📡 同步 upstream/main..."
git fetch upstream

echo "📡 更新 main..."
git checkout main
git rebase upstream/main

# ── 2. dry-run 或重建 ────────────────────────────
if $DRY_RUN; then
    echo ""
    echo "🔍 [dry-run] 将要 cherry-pick 的分支和提交:"
    if [[ ${#PR_BRANCHES[@]} -gt 0 ]]; then
        echo ""
        echo "  ── PR 分支 ──"
        for branch in "${PR_BRANCHES[@]}"; do
            print_branch_info "$branch" main
        done
    fi
    echo ""
    echo "  ── Private 分支 ──"
    for branch in "${PRIVATE_BRANCHES[@]}"; do
        print_branch_info "$branch" main
    done
    git checkout "$CURRENT_BRANCH"
    exit 0
fi

echo ""
echo "🔨 重建 integrate 分支..."
git checkout -B integrate main

# 先集成 PR 分支（基于 upstream/main 的干净改动）
for branch in "${PR_BRANCHES[@]}"; do
    cherry_pick_branch "$branch" main
done

# 再集成 private 分支（叠加在 PR 之上）
for branch in "${PRIVATE_BRANCHES[@]}"; do
    cherry_pick_branch "$branch" main
done

echo ""
echo "✅ integrate 重建完成"
echo "   基于: $(git log main --oneline -1)"
echo "   包含:"
for branch in "${PR_BRANCHES[@]}" "${PRIVATE_BRANCHES[@]}"; do
    if git rev-parse --verify "$branch" &>/dev/null; then
        count=$(git log main.."$branch" --oneline | wc -l | tr -d ' ')
        [[ "$count" -gt 0 ]] && echo "     $branch ($count commits)"
    fi
done
