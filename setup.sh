#!/bin/bash
# Claude Code 技能一键安装/同步脚本
#
# 两种用法都可以:
#   1. 一行式(公共仓库可用,无需 gh):
#        curl -fsSL https://raw.githubusercontent.com/gustyji/claude-skills-sync/main/setup.sh | bash
#   2. 私有仓库(需先 gh auth login):
#        gh repo clone gustyji/claude-skills-sync /tmp/sync && bash /tmp/sync/setup.sh
set -euo pipefail

SKILL_DIR="$HOME/.claude/skills"
MANIFEST_URL="https://raw.githubusercontent.com/gustyji/claude-skills-sync/main/manifest.json"

# 双模式定位 manifest:本地 clone 后跑则读文件,curl|bash 则下 URL
SCRIPT_PATH="${BASH_SOURCE[0]:-}"
if [ -n "$SCRIPT_PATH" ] && [ -f "$(dirname "$SCRIPT_PATH")/manifest.json" ]; then
  MANIFEST_DATA=$(cat "$(dirname "$SCRIPT_PATH")/manifest.json")
else
  MANIFEST_DATA=$(curl -fsSL "$MANIFEST_URL")
fi

# 选择 clone 命令:有 gh 且已登录则用 gh(支持私有),否则 git clone https
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  CLONE_CMD="gh"
else
  CLONE_CMD="git"
fi

echo "=== Claude Code 技能同步 ==="
echo "Clone 模式: $CLONE_CMD$([ "$CLONE_CMD" = "git" ] && echo " (公共仓库 only - 私有需 gh auth login)")"
mkdir -p "$SKILL_DIR"

SKILLS=$(printf '%s' "$MANIFEST_DATA" | python3 -c "
import json, sys
m = json.load(sys.stdin)
for s in m['skills']:
    print(s['name'] + '|' + s['repo'])
")

OK=0; FAIL=0; TOTAL=0

while IFS='|' read -r name repo; do
  [ -z "$name" ] && continue
  TOTAL=$((TOTAL + 1))
  dest="$SKILL_DIR/$name"

  if [ -d "$dest/.git" ]; then
    printf "  [%s] 更新..." "$name"
    if (cd "$dest" && git pull -q 2>/dev/null); then
      echo " OK"; OK=$((OK + 1))
    else
      echo " 失败"; FAIL=$((FAIL + 1))
    fi
  else
    printf "  [%s] 安装..." "$name"
    if [ "$CLONE_CMD" = "gh" ]; then
      ok=$(gh repo clone "$repo" "$dest" -- -q 2>/dev/null && echo y || echo n)
    else
      ok=$(git clone -q "https://github.com/$repo.git" "$dest" 2>/dev/null && echo y || echo n)
    fi
    if [ "$ok" = "y" ]; then
      echo " OK"; OK=$((OK + 1))
    else
      echo " 失败"; FAIL=$((FAIL + 1))
    fi
  fi
done <<< "$SKILLS"

# post_install 钩子(可选):当前 manifest 没有,留逻辑兜底
if [ -d "$SKILL_DIR/goal/goals" ] && [ ! -e "$HOME/.claude/goals" ]; then
  ln -s "$SKILL_DIR/goal/goals" "$HOME/.claude/goals"
  echo "  [goal] 符号链接已创建"
fi

find "$SKILL_DIR" -name "*.sh" -exec chmod +x {} + 2>/dev/null || true

echo ""
echo "=== 完成: $OK/$TOTAL 成功, $FAIL 失败 ==="
echo "启动 Claude Code 即可使用所有技能"
