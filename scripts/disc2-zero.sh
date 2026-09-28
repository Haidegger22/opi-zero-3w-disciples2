#!/bin/bash
# disc2-zero.sh — запуск Disciples II: Gold (русская версия) на Orange Pi Zero 3W.
#
# Что делает:
#   - гасит висячие сессии Wine (без этого новый запуск цепляется к мёртвому серверу);
#   - снимает мёртвые native-override'ы (в профиле остались от прошлых опытов,
#     а нативных DLL нет — из-за них игра падала до запуска);
#   - подставляет системный LD_LIBRARY_PATH (у вендорских libEGL/libGLESv2 от PowerVR
#     нет libGL, из-за чего Wine не может создать GL-контекст:
#     err:wgl:internal_context_create Failed to create internal thread context);
#   - запускает игру из её каталога.
#
# Настройка через переменные окружения:
#   WINEPREFIX  профиль Wine            (по умолчанию ~/.wine-hg2)
#   GAME_DIR    каталог с Discipl2.exe  (по умолчанию ~/d2-ru-pack/app)
#   DISPLAY     X-дисплей               (по умолчанию :0)
#
# Откат: удалить этот файл. Профиль и систему скрипт не меняет.

set -u

# --- 1) чистка мёртвых сессий Wine ---
timeout 25 wineserver -k 2>/dev/null; sleep 2
pkill -x Discipl2.exe 2>/dev/null; sleep 1
pkill -x wineserver 2>/dev/null; sleep 1
rm -f /tmp/.wine-1000/server-* 2>/dev/null

GAME_DIR="${GAME_DIR:-$HOME/d2-ru-pack/app}"
export WINEPREFIX="${WINEPREFIX:-$HOME/.wine-hg2}"
export DISPLAY="${DISPLAY:-:0}"

# --- 2) builtin-библиотеки Wine вместо отсутствующих нативных ---
export WINEDLLOVERRIDES="ddraw=b;d3d8=b;d3d9=b;d3d10core=b;d3d11=b;dxgi=b"

# --- 3) системные библиотеки вместо вендорских из /usr/local/lib ---
export LD_LIBRARY_PATH="/usr/lib/aarch64-linux-gnu:/lib/aarch64-linux-gnu"

# --- 4) проверки перед запуском ---
if [ ! -f "$WINEPREFIX/system.reg" ]; then
    echo "Нет профиля Wine: $WINEPREFIX" >&2
    echo "Создайте его и вылечите реестр: fix-rpcss-service.sh / fix-mmdevenum.sh" >&2
    exit 1
fi
if ! grep -q 'bcde0395' "$WINEPREFIX/system.reg"; then
    echo "ВНИМАНИЕ: COM-класс MMDeviceEnumerator не зарегистрирован — звука не будет." >&2
    echo "Вылечите: fix-mmdevenum.sh $WINEPREFIX" >&2
fi

cd "$GAME_DIR" || { echo "Не найден каталог игры: $GAME_DIR" >&2; exit 1; }

echo "Запускаю Disciples II: Gold (русская версия)... профиль $WINEPREFIX"
wine Discipl2.exe "$@"
echo "Игра закрыта."
