#!/bin/bash
# ============================================================
# save_progress.sh — VSG 项目代码变更快速提交脚本
# 用法：./save_progress.sh "本次修改说明"
# 示例：./save_progress.sh "优化奖励函数，加入 dω/dt 惩罚项"
# ============================================================

cd "$(dirname "$0")"

MSG="${1:-"代码更新（无说明）"}"

echo "===== VSG 项目进度保存 ====="
echo ""

# 显示当前变更
echo "[变更文件]"
git diff --name-only
git ls-files --others --exclude-standard
echo ""

# 暂存所有 .m 文件和 .mdl 文件的变更
git add *.m *.mdl CHANGELOG.md 2>/dev/null
git add "Three_Phase_VSG_Double_Loop_Control.mdl/" 2>/dev/null

# 检查是否有东西要提交
if git diff --cached --quiet; then
    echo "没有检测到代码变更，无需提交。"
    exit 0
fi

# 提交
git commit -m "$(date '+%Y-%m-%d') | $MSG"

echo ""
echo "✓ 提交成功！"
echo ""
echo "[最近提交记录]"
git log --oneline -5
