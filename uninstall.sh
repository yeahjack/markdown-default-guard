#!/bin/bash
set -euo pipefail
label='io.github.markdown-default-guard'
launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$label.plist"
directory="$HOME/Library/Application Support/MarkdownDefaultGuard"
rm -f "$directory/markdown-default-guard" "$directory/before-install.txt"
rmdir "$directory" 2>/dev/null || true
echo '已卸载。当前默认打开方式和历史日志保持不变。'
