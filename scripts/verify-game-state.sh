#!/bin/bash
# verify-game-state.sh — снимок состояния игры: запущена ли, какое окно, что в настройках.
# Только чтение, ничего не меняет. Удобно перед правкой Disciple.ini и после неё.
set -u
GAME="${GAME_DIR:-$HOME/d2-ru-pack/app}"
INI="$GAME/Disciple.ini"
export DISPLAY="${DISPLAY:-:0}"

echo "=== процесс и окно ==="
P=$(pgrep -x Discipl2.exe | head -1)
if [ -n "$P" ]; then
    echo "   Discipl2.exe: PID $P, CPU $(ps -p "$P" -o pcpu= | xargs)%, работает $(ps -p "$P" -o etime= | xargs), RSS $(ps -p "$P" -o rss= | xargs | awk '{printf "%.0f МБ", $1/1024}')"
    W=$(xdotool search --name 'Disciples' 2>/dev/null | head -1)
    [ -n "$W" ] && echo "   окно: $(xdotool getwindowgeometry --shell "$W" | grep -aE 'WIDTH|HEIGHT' | tr '\n' ' ') (id $W)"
else
    echo "   не запущена (wineserver: $(pgrep -xc wineserver 2>/dev/null | head -1))"
fi
echo "   режим экрана: $(xrandr 2>/dev/null | grep -aE ' connected|\*' | tr '\n' ' ')"

echo
echo "=== настройки, которые сейчас в силе ==="
[ -f "$INI" ] || { echo "   нет файла $INI"; exit 1; }
iconv -f cp1251 -t utf-8 "$INI" | tr -d '\r' | grep -aE \
 '^(DisplayMode|UseD3D|DisplayWidth|DisplayHeight|HD|ImageAspect|ImageVSync|Renderer|Interpolation|Upscaling|FullScreenMode|SpeedEnabled|GameSpeed|PlayerSpeed|OpponentSpeed|ScrollSpeed|BattleSpeed|BattleAnim|FastAI|MouseScroll)=' \
 | sed 's/^/   /'

echo
echo "=== бэкапы настроек (последние 5) ==="
ls -t "$GAME"/Disciple.ini.backup-* 2>/dev/null | head -5 | while read -r f; do
    echo "   $(basename "$f")  $(stat -c '%y' "$f" | cut -c1-19)"
done

echo
echo "=== GPU занята игрой? (софтверный DirectDraw её не берёт) ==="
if [ -n "$P" ]; then
    n=$(ls -l /proc/$P/fd 2>/dev/null | grep -ac renderD128)
    echo "   дескрипторов на /dev/dri/renderD128: $n"
else
    echo "   игра не запущена"
fi
