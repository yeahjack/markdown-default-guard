# Markdown 默认打开方式守护

把 Markdown 文件设成用 VS Code 打开后，又被 WorkBuddy 改了回去？这个小工具会定时检查，发现后尝试恢复。

它默认每 30 秒检查一次：只有默认应用变成 WorkBuddy 时才恢复；你选了其他编辑器，它不会干预。每次检查完立即退出进程，不扫描文件内容，也不联网。

默认恢复为 VS Code，也支持换成 Typora 等编辑器。它在下一次检查时处理改动，不会提前拦截。

## 手动安装

**系统要求**：macOS 12 或更高版本、已安装的 Markdown 编辑器，以及 Apple 命令行工具。目前仅在 macOS 26.5 上实测过编译与定时运行，其他版本暂未测试。

首次使用命令行工具时，先在终端运行以下命令完成安装（已安装请跳过）：

```sh
xcode-select --install
```

克隆仓库并安装：

```sh
git clone https://github.com/yeahjack/markdown-default-guard.git
cd markdown-default-guard
bash install.sh
```

安装脚本会在本机编译 Swift 源码，并为当前用户注册后台任务（开机登录后自动启动）。不需要 sudo，也不依赖 Homebrew 或 Python。后续重新运行该安装命令，即可同步更新程序与配置。

请先在“访达”中选中任意 Markdown 文件，打开“显示简介”（`Cmd + I`），在“打开方式”中选好 VS Code 并点击“全部更改”。守护程序只处理 WorkBuddy 覆盖的情况，不会替你更换其他默认应用。

检查当前的默认关联：

```sh
"$HOME/Library/Application Support/MarkdownDefaultGuard/markdown-default-guard" --check
```

如果只想测试能否正常编译、暂不注册后台任务，可以运行：

```sh
bash install.sh --check-only
```

## 让 Agent 安装

直接把以下内容发给你在本机使用的编程 Agent：

> 请阅读 markdown-default-guard 仓库的 README 与安装脚本，在我的当前 macOS 账户下完成安装。默认恢复到 VS Code，每 30 秒检查一次。先确认编辑器路径与 Apple 命令行工具可用，再先后运行 `bash install.sh --check-only` 和 `bash install.sh`。不要使用 sudo。安装后检查 LaunchAgent 状态以及当前的 Markdown 打开方式关联；如果系统弹出权限确认弹窗，请提示我手动确认。不要为了测试把默认应用临时改成 WorkBuddy，也不要上传本机的日志、用户名、路径或系统配置。

Agent 可以运行以下命令确认任务是否正常加载。因为程序检查完毕后会自动退出，`state = not running` 本身不代表出错，结合 `runs`（运行次数）和 `last exit code`（退出码）判断即可：

```sh
launchctl print "gui/$(id -u)/io.github.markdown-default-guard"
```

## 换成其他 Markdown 阅读器

在安装时传入 `--app` 参数指定应用路径即可，无需改动 Swift 源码。例如指定 Typora：

```sh
bash install.sh --app "/Applications/Typora.app"
```

重新安装后，以后再被 WorkBuddy 覆盖时，程序会尝试恢复为 Typora。你依然需要在“访达”中手动把当前打开方式设为 Typora；该参数仅用于指定“被覆盖后恢复成谁”。

如需让 Agent 代劳，替换下方提示词中的应用名称即可：

> 请把 markdown-default-guard 的恢复目标从 VS Code 改为 Typora。先定位本机已安装的 Typora.app 路径，运行 `bash install.sh --app "实际应用路径"` 更新任务，并核对 LaunchAgent 的 ProgramArguments。随后引导我在“访达”中将 Markdown 默认打开方式设为 Typora，最后通过 `--app "实际应用路径" --check` 校验。不要修改源码，也不要把默认应用临时改成 WorkBuddy。

指定自定义编辑器后，手动执行 `--check` 时也需带上对应的 `--app` 参数（后台任务会自动记住安装时的路径）。若要调整检查频率，可追加 `--interval <秒数>` 参数（支持 10–86400 秒），例如 `--interval 60`。

## 资源开销与实测状态

**资源开销**：早期版本在一台 Mac 上连续执行了 50 次只读检查，单次耗时中位数为 7.5 毫秒，平均 CPU 时间 5.3 毫秒，峰值内存约 15.5 MiB。按 30 秒检查一次折算，工具本身平均占用单核 CPU 约 0.018%（该数据不含系统调度开销，也不代表实际电池功耗）。

**实测情况**：定时调度与设置目标应用的原生系统接口均已验证通过。但在测试中，系统直接取消了切换到 WorkBuddy 的请求，因此“从 WorkBuddy 自动恢复”的完整流程暂未实测成功。若 macOS 弹出安全提示，需手动点击允许；程序会记录恢复结果或错误。

## 查看日志与卸载

程序仅记录恢复动作和报错信息，文件保存在本地：

```sh
tail -n 20 "$HOME/Library/Logs/MarkdownDefaultGuard.log"
```

若从未触发恢复且无报错，该日志文件可能不存在。日志单文件超过约 256 KiB 后会自动滚动，保留 1 份历史备份。程序不读取文档内容，也不上传数据。

如需卸载，在仓库根目录下运行以下命令即可（会保留当前的默认打开方式与历史日志）：

```sh
bash uninstall.sh
```
