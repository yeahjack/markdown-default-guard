#!/bin/bash
set -euo pipefail
app='/Applications/Visual Studio Code.app'
interval=30
check_only=false
while [ "$#" -gt 0 ]; do
  case "$1" in
    --app) [ "$#" -ge 2 ] || exit 2; app="$2"; shift 2 ;;
    --interval) [ "$#" -ge 2 ] || exit 2; interval="$2"; shift 2 ;;
    --check-only) check_only=true; shift ;;
    *) echo "用法：bash install.sh [--app /Applications/阅读器.app] [--interval 30] [--check-only]"; exit 2 ;;
  esac
done
[ "$(uname -s)" = Darwin ] || { echo '仅支持 macOS'; exit 1; }
[ "$(id -u)" -ne 0 ] || { echo '请用当前用户运行，不要加 sudo'; exit 1; }
case "$app" in /*.app) ;; *) echo '请提供 .app 的绝对路径'; exit 2 ;; esac
case "$interval" in ''|*[!0-9]*) echo '检查间隔应为整数秒'; exit 2 ;; esac
[ "$interval" -ge 10 ] && [ "$interval" -le 86400 ] || { echo '检查间隔应为 10–86400 秒'; exit 2; }
[ -d "$app" ] || { echo "找不到应用：$app"; exit 1; }
xcrun --find swiftc >/dev/null 2>&1 || { echo '请先运行 xcode-select --install 安装命令行工具'; exit 1; }
root="$(cd "$(dirname "$0")" && pwd)"
temp="$(mktemp -d)"
trap 'rm -rf "$temp"' EXIT
xcrun swiftc -O -module-cache-path "$temp/cache" "$root/src/guard.swift" -o "$temp/markdown-default-guard"
"$temp/markdown-default-guard" --self-test
"$temp/markdown-default-guard" --app "$app" --check
if $check_only; then echo '编译与只读检查通过，未安装后台任务'; exit 0; fi
label='io.github.markdown-default-guard'
destination="$HOME/Library/Application Support/MarkdownDefaultGuard"
agent="$HOME/Library/LaunchAgents/$label.plist"
mkdir -p "$destination" "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
chmod 700 "$destination"
"$temp/markdown-default-guard" --app "$app" --check > "$destination/before-install.txt"
cp "$temp/markdown-default-guard" "$destination/markdown-default-guard.new"
chmod 755 "$destination/markdown-default-guard.new"
mv -f "$destination/markdown-default-guard.new" "$destination/markdown-default-guard"
config="$temp/agent.plist"
plutil -create xml1 "$config"
plutil -insert Label -string "$label" "$config"
plutil -insert ProgramArguments -array "$config"
plutil -insert ProgramArguments.0 -string "$destination/markdown-default-guard" "$config"
plutil -insert ProgramArguments.1 -string '--app' "$config"
plutil -insert ProgramArguments.2 -string "$app" "$config"
plutil -insert RunAtLoad -bool YES "$config"
plutil -insert StartInterval -integer "$interval" "$config"
plutil -insert ProcessType -string Background "$config"
plutil -insert LowPriorityIO -bool YES "$config"
plutil -insert Nice -integer 10 "$config"
plutil -lint "$config"
launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
cp "$config" "$agent"
chmod 644 "$agent"
launchctl bootstrap "gui/$(id -u)" "$agent"
echo "已安装：每 $interval 秒检查一次；恢复目标为 $app"
