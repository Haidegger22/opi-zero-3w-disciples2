#!/bin/bash
# set-resolution.sh <ширина> <высота> — разрешение картинки игры в Disciple.ini (секция [Wrapper]).
#
# На Zero 3W экран 1024×600, поэтому рабочее значение 1024 600: игра рисует ровно
# в режим экрана и кадр не растягивается (по умолчанию сборка идёт с 800×600).
# Требует HD=1 — без него нестандартные разрешения не работают.
#
# Использование: ./set-resolution.sh 1024 600
set -u
GAME="${GAME_DIR:-$HOME/d2-ru-pack/app}"
INI="$GAME/Disciple.ini"
W="${1:?нужна ширина, например 1024}"
H="${2:?нужна высота, например 600}"
SET="$(dirname "$0")/d2-ini-set.sh"

[ -f "$SET" ] || SET="$HOME/.local/bin/d2-ini-set.sh"
[ -f "$INI" ] || { echo "нет файла $INI (задайте GAME_DIR)"; exit 1; }

echo "=== проверяю, что HD включён (иначе разрешение не подействует) ==="
iconv -f cp1251 -t utf-8 "$INI" | grep -aiE '^HD=' | tr -d '\r' | sed 's/^/   /'

"$SET" DisplayWidth  "$W"
"$SET" DisplayHeight "$H"

echo "=== проверка на живом окне (если игра запущена) ==="
export DISPLAY="${DISPLAY:-:0}"
W_ID=$(xdotool search --name 'Disciples' 2>/dev/null | head -1)
if [ -n "$W_ID" ]; then
    xdotool getwindowgeometry --shell "$W_ID" 2>/dev/null | grep -aE 'WIDTH|HEIGHT' | sed 's/^/   окно: /'
else
    echo "   игра не запущена — размер окна проверить нечем, запустите и гляньте:"
    echo "   DISPLAY=:0 xdotool search --name 'Disciples' | xargs -I{} xdotool getwindowgeometry --shell {}"
fi
echo "   режим экрана: $(xrandr 2>/dev/null | grep -aE ' connected|\*' | tr '\n' ' ')"
echo
echo "Дальше по вкусу (см. docs/WRAPPER-AND-GAME-SETTINGS.md):"
echo "   ImageAspect=1 — сохранять пропорции; Upscaling=1..5 — фильтры xBRZ/ScaleHQ/Eagle"
echo "   SpeedEnabled=0 — выключить ускоритель анимации обёртки (GameSpeed=5 = 1,5×)"
