#!/bin/bash
# Claude Code 技能一键安装/同步脚本
# 前提: 新设备需先运行 gh auth login
# 用法: gh repo clone gustyji/claude-skills-sync /tmp/claude-skills-sync && bash /tmp/claude-skills-sync/setup.sh
set -euo pipefail

SKILL_DIR="$HOME/.claude/skills"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$SCRIPT_DIR/manifest.json"

echo "=== Claude Code 技能同步 ==="

# 检查 gh 是否已登录
if ! gh auth status &>/dev/null; then
  echo "错误: 请先运行 gh auth login 登录 GitHub"
  exit 1
fi

mkdir -p "$SKILL_DIR"

# 解析技能列表
SKILLS=$(python3 -c "
import json
m = json.load(open('$MANIFEST'))
for s in m['skills']:
    print(s['name'] + '|' + s['repo'])
")

OK=0; FAIL=0; TOTAL=0

while IFS='|' read -r name repo; do
  TOTAL=$((TOTAL + 1))
  dest="$SKILL_DIR/$name"

  if [ -d "$dest/.git" ]; then
    printf "  [%s] 更新..." "$name"
    if (cd "$dest" && git pull -q 2>/dev/null); then
      echo " OK"
      OK=$((OK + 1))
    else
      echo " 失败"
      FAIL=$((FAIL + 1))
    fi
  else
    printf "  [%s] 安装..." "$name"
    if gh repo clone "$repo" "$dest" -- -q 2>/dev/null; then
      echo " OK"
      OK=$((OK + 1))
    else
      echo " 失败"
      FAIL=$((FAIL + 1))
    fi
  fi
done <<< "$SKILLS"

# 后置操作: 创建符号链接
if [ -d "$SKILL_DIR/goal/goals" ] && [ ! -e "$HOME/.claude/goals" ]; then
  ln -s "$SKILL_DIR/goal/goals" "$HOME/.claude/goals"
  echo "  [goal] 符号链接已创建"
fi

# 确保脚本可执行
find "$SKILL_DIR" -name "*.sh" -exec chmod +x {} \; 2>/dev/null

echo ""
echo "=== 完成: $OK/$TOTAL 成功, $FAIL 失败 ==="
echo "启动 Claude Code 即可使用所有技能"
