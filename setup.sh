#!/bin/bash
# Claude Code 技能一键安装/同步脚本
# 用法: curl -fsSL https://raw.githubusercontent.com/gustyji/claude-skills-sync/main/setup.sh | bash
set -euo pipefail

SKILL_DIR="$HOME/.claude/skills"
MANIFEST_URL="https://raw.githubusercontent.com/gustyji/claude-skills-sync/main/manifest.json"

echo "=== Claude Code 技能同步 ==="
mkdir -p "$SKILL_DIR"

# 下载 manifest
MANIFEST=$(curl -fsSL "$MANIFEST_URL")

# 解析技能列表
SKILLS=$(echo "$MANIFEST" | python3 -c "
import json, sys
m = json.load(sys.stdin)
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
    if git clone -q "https://github.com/$repo.git" "$dest" 2>/dev/null; then
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
