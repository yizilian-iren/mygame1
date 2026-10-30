#!/bin/bash
# 自动试玩（tests/playtest.gd），headless。全部通过 exit 0，否则 exit 1。
# Godot 遇到脚本语法错误时自己也 exit 0，所以以最后的「FAILS: 0」为准。
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-$HOME/tools/godot/Godot.app/Contents/MacOS/Godot}
log=$(mktemp)
trap 'rm -f "$log"' EXIT
"$GODOT" --headless --path . -s tests/playtest.gd > "$log" 2>&1
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
