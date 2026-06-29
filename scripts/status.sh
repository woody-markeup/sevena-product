#!/usr/bin/env bash
# 跨 repo 進度查詢:匯總雙邊子專案的分支、未提交變更與近期 commit。
# 用法:./scripts/status.sh [近期 commit 筆數,預設 8]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
N="${1:-8}"
REPOS=("sevena" "sevena-backend")

for name in "${REPOS[@]}"; do
  dir="$ROOT/$name"
  echo "========================================================"
  echo "📦 $name"
  echo "========================================================"
  if [ ! -d "$dir/.git" ]; then
    echo "  ⚠️  尚未 clone (找不到 $dir/.git)"
    echo
    continue
  fi

  branch="$(git -C "$dir" branch --show-current 2>/dev/null || echo '(detached)')"
  echo "  分支: $branch"

  # 未提交變更
  dirty="$(git -C "$dir" status --porcelain | wc -l | tr -d ' ')"
  if [ "$dirty" -gt 0 ]; then
    echo "  狀態: ⚠️  $dirty 個未提交變更"
  else
    echo "  狀態: ✅ 乾淨"
  fi

  # 與 origin 的領先/落後 (若有對應的 upstream)
  if git -C "$dir" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
    ahead_behind="$(git -C "$dir" rev-list --left-right --count '@{u}'...HEAD 2>/dev/null || echo '0	0')"
    behind="$(echo "$ahead_behind" | cut -f1)"
    ahead="$(echo "$ahead_behind" | cut -f2)"
    echo "  vs origin: ↑$ahead 未推送 / ↓$behind 未拉取"
  fi

  echo "  近期 $N 筆 commit:"
  git -C "$dir" log --oneline -"$N" --pretty='    %h  %ad  %s' --date=short 2>/dev/null || echo "    (無紀錄)"
  echo
done
