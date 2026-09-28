#!/bin/bash
# set-fullscreen.sh — полный экран / окно для Disciples II (файл Disciple.ini, ключ DisplayMode).
#
# Сам файл игры подсказывает: «; 0=full-screen, 1 = windowed» — это про DisplayMode.
# Проверено на Zero 3W 28.09.2026: при DisplayMode=0 окно игры занимает весь экран
# 1024x600 (xdotool: X=0 Y=0 WIDTH=1024 HEIGHT=600, _NET_WM_STATE_FULLSCREEN).
#
# Использование:
#     ./set-fullscreen.sh            # включить полный экран (DisplayMode=0)
#     ./set-fullscreen.sh windowed   # вернуть окно (DisplayMode=1)
#     ./set-fullscreen.sh test       # включить полный экран и проверить геометрию запуском
#
# Правка идёт в копии файла игры; бэкап создаётся рядом (Disciple.ini.backup-ГГГГММДД-ЧЧММ).
# Откат: cp Disciple.ini.backup-* Disciple.ini
set -u
export DISPLAY="${DISPLAY:-:0}"

GAME_DIR="${GAME_DIR:-$HOME/d2-ru-pack/app}"
INI="$GAME_DIR/Disciple.ini"
export WINEPREFIX="${WINEPREFIX:-$HOME/.wine-hg2}"
MODE="${1:-full}"

case "$MODE" in
    windowed|1) VAL=1; WORD="окно" ;;
    full|0|*)   VAL=0; WORD="полный экран" ;;
esac

[ -f "$INI" ] || { echo "Не найден $INI — проверьте GAME_DIR"; exit 1; }

echo "=== 1) бэкап и текущее значение ==="
STAMP=$(date +%Y%m%d-%H%M)
cp -a "$INI" "$INI.backup-$STAMP" && echo "   бэкап: $INI.backup-$STAMP"
echo "   было: $(grep -a DisplayMode "$INI" | tr -d '\r')"

echo
echo "=== 2) ставлю DisplayMode=$VAL ($WORD) ==="
python3 - "$INI" "$VAL" <<'PY'
import sys, io, re
p, val = sys.argv[1], sys.argv[2]
with io.open(p, 'r', encoding='cp1251', errors='surrogateescape', newline='') as f:
    data = f.read()
out = re.sub(r'(?m)^DisplayMode\s*=\s*\d+', 'DisplayMode=%s' % val, data)
with io.open(p, 'w', encoding='cp1251', errors='surrogateescape', newline='') as f:
    f.write(out)
print("   стало:", [l.strip() for l in out.splitlines() if l.startswith('DisplayMode')])
PY

if [ "$MODE" = "test" ]; then
    echo
    echo "=== 3) проверка запуском (30 с) ==="
    timeout -s KILL 25 wineserver -k 2>/dev/null; sleep 2
    pkill -x Discipl2.exe 2>/dev/null; sleep 1
    cd "$GAME_DIR" || exit 1
    env -u LD_LIBRARY_PATH \
        LD_LIBRARY_PATH=/usr/lib/aarch64-linux-gnu:/lib/aarch64-linux-gnu \
        WINEDLLOVERRIDES="ddraw=b;d3d8=b;d3d9=b;d3d10core=b;d3d11=b;dxgi=b" \
        nohup wine Discipl2.exe > /tmp/fullscreen-check.log 2>&1 &
    for t in 10 20 30; do
        sleep 10
        W=$(xdotool search --name "Disciples" 2>/dev/null | head -1)
        [ -n "$W" ] && break
    done
    if [ -n "$W" ]; then
        echo "   окно: $(xdotool getwindowgeometry --shell "$W" | tr '\n' ' ')"
        echo "   состояние: $(xprop -id "$W" _NET_WM_STATE 2>/dev/null | cut -d= -f2)"
    else
        echo "   окно не появилось, лог: /tmp/fullscreen-check.log"
    fi
    pkill -x Discipl2.exe 2>/dev/null; sleep 2
    timeout -s KILL 30 wineserver -k 2>/dev/null
fi

echo
echo "=== ИТОГ: DisplayMode=$(grep -a DisplayMode "$INI" | tr -d '\r' | cut -d= -f2)"
