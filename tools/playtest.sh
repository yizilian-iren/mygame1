#!/bin/bash
# 自动试玩（tests/playtest.gd），headless。全部通过 exit 0，否则 exit 1。
# Godot 遇到脚本语法错误时自己也 exit 0，所以以最后的「FAILS: 0」为准。
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-$HOME/tools/godot/Godot.app/Contents/MacOS/Godot}
log=$(mktemp)
trap 'rm -f "$log"' EXIT
# 先 import：pull 来的新素材没 import 时 i18n 等脚本加载失败，测试不会 quit，Godot 会一直挂着。
# 已经 import 过的只要 2 秒左右。再加个超时，万一还是卡住也不会一直等下去。
"$GODOT" --headless --path . --import > /dev/null 2>&1
timeout 120 "$GODOT" --headless --path . -s tests/playtest.gd > "$log" 2>&1
[ $? -eq 124 ] && echo "playtest: Godot 120 秒没结束，被停掉了"
grep -E "^(FAIL |SCRIPT ERROR|Parse Error)|Error calling" "$log"
# 游戏脚本自己报的 ERROR（Node not found、发不存在的 signal 之类）也算不过：backtrace 第一行在 scripts/ 里的
game_errors=$(grep -A4 "^ERROR:" "$log" | awk '/^ERROR:/{e=$0} /\[0\] .*res:\/\/scripts\//{print e}' | sort -u)
[ -n "$game_errors" ] && echo "$game_errors"
if grep -q "^FAILS: 0$" "$log" && [ -z "$game_errors" ]; then
	echo "playtest: all $(grep -c '^ok ' "$log") checks passed"
else
	echo "playtest: FAILED ($(grep -c '^FAIL ' "$log") failed, $(printf '%s' "$game_errors" | grep -c .) game errors; full log: GODOT ... -s tests/playtest.gd)"
	exit 1
fi
