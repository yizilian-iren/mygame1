#!/bin/bash
# 把 Windows 版放到 home4070 的 D:\Games\mygame1\（I-8）。只放文件，不启动：
# 从 ssh 启动的程序不会出现在桌面上，放好后让用户在 home4070 上双击 mygame1.exe。
# 走 home4070 的 WSL（/mnt/d 就是 D 盘）；m4 直连 Windows 那层的 ssh 不通。C 盘快满了，别放 C 盘。
#
# 用法：
#   tools/deploy_home4070.sh               本机导出一份 Windows 版再放过去
#   tools/deploy_home4070.sh v0.2          用 GitHub Release v0.2 里的 Windows zip（要 gh）
#   tools/deploy_home4070.sh path/to.exe   放指定的 exe
set -euo pipefail
cd "$(dirname "$0")/.."
HOST=${HOME4070_HOST:-home4070}
DEST=/mnt/d/Games/mygame1
GODOT=${GODOT:-$HOME/tools/godot/Godot.app/Contents/MacOS/Godot}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

src=${1:-}
if [[ -z "$src" ]]; then
	"$GODOT" --headless --path . --export-release "Windows Desktop" "$tmp/mygame1.exe" > "$tmp/export.log" 2>&1 \
		|| { tail -20 "$tmp/export.log"; exit 1; }
	exe="$tmp/mygame1.exe"; label="local $(git rev-parse --short HEAD)"
elif [[ -f "$src" ]]; then
	exe="$src"; label="$src"
else
	gh release download "$src" --pattern '*-windows.zip' --dir "$tmp"
	unzip -q -o "$tmp"/*-windows.zip -d "$tmp/zip"
	exe="$tmp/zip/mygame1.exe"; label="release $src"
fi
[[ -s "$exe" ]] || { echo "no exe: $exe" >&2; exit 1; }

ssh -o ClearAllForwardings=yes "$HOST" "mkdir -p '$DEST'"
# 游戏开着时 exe 被锁，覆盖会失败：先放成临时名，成功后再改名
scp -q -o ClearAllForwardings=yes "$exe" "$HOST:$DEST/mygame1.exe.new"
ssh -o ClearAllForwardings=yes "$HOST" "cd '$DEST' && mv -f mygame1.exe.new mygame1.exe && printf '%s\n' '$label' \"\$(date '+%F %T')\" > version.txt && ls -la '$DEST'" \
	|| { echo "mygame1.exe 可能正开着：关掉游戏再跑一次" >&2; exit 1; }
echo "放好了：home4070 上双击 D:\\Games\\mygame1\\mygame1.exe（$label）"
