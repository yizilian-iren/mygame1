# mygame1（爆杀小怪兽）

Godot 4.5.1 做的横版射击小游戏。网页版：https://yizilian-iren.github.io/mygame1/

## 改完先跑 playtest

```sh
tools/playtest.sh          # headless 自动试玩，约 15 秒；全部通过才 exit 0
```

`tests/playtest.gd` 会走一遍：键盘移动和换武器、自动射击打死怪、升级弹出三个选项并选一个、升级按钮每次停在同一位置、三种语言切换和字体覆盖、手机的摇杆和 SWITCH、GAME OVER 后重开。改了玩法或界面，就在这里补检查。Godot 遇到脚本语法错误时也 exit 0，所以要用 `tools/playtest.sh`，别直接看 Godot 的退出码。

要给用户看画面：`tools/record_clip.sh [目录] [en|ja|zh]` 用 Movie Maker 录约 8 秒（会在本机开一个窗口），输出 PNG 帧和 Deck 评审卡片用的 `frames.json`。

## 命令

`G=~/tools/godot/Godot.app/Contents/MacOS/Godot`（m4）

- 新 checkout 先 `$G --headless --path . --import`（约 1 分钟）。
- 本机导出：`$G --headless --path . --export-release "Web" Bulids/Web/index.html`，`"Windows Desktop" Bulids/Windows/mygame1.exe`，`"macOS" Bulids/macOS/mygame1-macos.zip`。
- Windows 版放到 home4070 试玩：`tools/deploy_home4070.sh`（本机导出）或 `tools/deploy_home4070.sh v0.2`（用 Release 里的）。

## 发布

- `Bulids/` 不进 git。push 到 main → `.github/workflows/pages.yml` 在 Actions 里导出 Web 并**直接发布到线上**，所以 worker 不推 main，由 main agent 审过再推。
- push `v*` tag → `release.yml` 导出 Windows 和 macOS，放进 GitHub Release（带横线的 tag 是 prerelease）。

## 约定

- 所有界面文字走 `i18n/strings.csv`（keys,en,ja,zh）：场景里写 key，代码里用 `tr()`。语言由 autoload `scripts/i18n.gd` 管。
- 界面字体用 `AssetBundle/Fonts/ui_font.tres`：英文、中文是 Uranus（中文像素字体），日语整段换成 DotGothic16（Uranus 缺很多日文字）。新加的文字要在三种语言下都有字形（playtest 会查）。两个字体都关了 system fallback，电脑上看到的和网页一样。
- headless 测试里模拟触摸，坐标要乘 `root.get_final_transform()`；等待用游戏时间（`create_timer`），不用真实时间。
- 改场景里的资源引用后，import 不应该有 `invalid UID` warning。
