#!/bin/bash
# 带画面跑 tests/playtest.gd 的 --demo 那一段（约 8 秒：走、打死怪、升级、选、换武器），
# 用 Godot 的 Movie Maker 录成 PNG 帧，再写 Deck 评审卡片要的 frames.json（最多 240 帧）。
# 会在本机桌面上开一个游戏窗口，录完自己关。
# 用法：tools/record_clip.sh [输出目录，默认 /tmp/mygame1-clip] [语言 en/ja/zh] [窗口大小 WxH，默认 1152x648] [touch]
#   例：tools/record_clip.sh /tmp/clip-phone ja 1404x648 touch  （iPhone 横屏 19.5:9，显示摇杆和 SWITCH）
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-$HOME/tools/godot/Godot.app/Contents/MacOS/Godot}
OUT=${1:-/tmp/mygame1-clip}
LANG_ARG=${2:-en}
RES=${3:-1152x648}
TOUCH=${4:+--touch}
FPS=30
rm -rf "$OUT" && mkdir -p "$OUT/raw"
"$GODOT" --path . --rendering-driver opengl3 --write-movie "$OUT/raw/frame.png" --fixed-fps $FPS \
	--resolution "$RES" -s tests/playtest.gd -- --demo --lang=$LANG_ARG $TOUCH > "$OUT/godot.log" 2>&1
python3 - "$OUT" $FPS <<'PY'
import json, os, shutil, sys
out, fps = sys.argv[1], int(sys.argv[2])
raw = sorted(f for f in os.listdir(f"{out}/raw") if f.endswith(".png"))
if not raw:
    sys.exit(f"no frames recorded; see {out}/godot.log")
step = max(1, -(-len(raw) // 240))  # 超过 240 帧就隔帧取
frames, times = [], []
for i, name in enumerate(raw[::step]):
    dst = f"frame-{i:03d}.png"
    shutil.move(f"{out}/raw/{name}", f"{out}/{dst}")
    frames.append(dst)
    times.append(round(raw.index(name) * 1000 / fps, 1))
shutil.rmtree(f"{out}/raw")
json.dump({"times": times, "frames": frames}, open(f"{out}/frames.json", "w"))
print(f"{len(frames)} frames ({len(raw)} recorded, {len(raw) / fps:.1f} s) -> {out}/frames.json")
PY
