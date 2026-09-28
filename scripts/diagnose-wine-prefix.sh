#!/bin/bash
# diagnose-wine-prefix.sh — что именно потеряно в реестре профиля Wine и как это лечить.
# Ничего не меняет, только читает.
#
# Использование: ./diagnose-wine-prefix.sh [WINEPREFIX]   (по умолчанию ~/.wine-hg2)
set -u

W="${1:-$HOME/.wine-hg2}"
GUID='{bcde0395-e52f-467c-8e3d-c4579291692e}'
export WINEPREFIX="$W"
export DISPLAY="${DISPLAY:-:0}"
export LD_LIBRARY_PATH="/usr/lib/aarch64-linux-gnu:/lib/aarch64-linux-gnu"

fail=0

echo "=============================================================="
echo "Диагностика профиля Wine: $W"
echo "=============================================================="
echo "wine: $(wine --version 2>&1)"
if [ ! -f "$W/system.reg" ]; then
    echo "!! Профиль не найден (нет system.reg) — неверный путь"
    exit 1
fi
echo "system.reg: $(stat -c%s "$W/system.reg") байт, ключей: $(grep -c '^\[' "$W/system.reg")"

echo
echo "--- 1) ОСНОВНОЙ ВОПРОС: какие службы wine.inf прописаны в профиле"
INF=/usr/share/wine/wine.inf
if [ -f "$INF" ]; then
    total=0; missing=0
    for s in $(grep -oP '^AddService=\K[^,]+' "$INF" | sort -u); do
        total=$((total+1))
        if ! grep -aq "Services\\\\$s\]" "$W/system.reg"; then
            echo "    ОТСУТСТВУЕТ: $s"
            missing=$((missing+1))
        fi
    done
    echo "    итого в wine.inf: $total, отсутствует в профиле: $missing"
    if [ "$missing" -gt 0 ]; then
        fail=1
        echo "    -> лечится scripts/fix-rpcss-service.sh (для RpcSs);
           остальные службы восстанавливаются прогоном wineboot на рабочем профиле"
    fi
else
    echo "    wine.inf не найден ($INF) — пропускаю проверку"
fi

echo
echo "--- 2) служба RpcSs (её отсутствие даёт 'Failed to open RpcSs service')"
if grep -aq 'Services\\\\RpcSs\]' "$W/system.reg"; then
    echo "    ключ в реестре: ЕСТЬ"
    grep -an -A8 'Services\\\\RpcSs\]' "$W/system.reg" | head -10 | sed 's/^/      /'
else
    echo "    ключ в реестре: НЕТ  -> wine sc query вернёт 1060 (служба не существует)"
    fail=1
fi
echo "    ответ SCM:"
timeout 60 wine sc query RpcSs 2>&1 | grep -aviE 'actctx|^\s*$' | head -6 | sed 's/^/      /'
echo "      (exit-код sc: $(timeout 60 wine sc query RpcSs >/dev/null 2>&1; echo $?) — 1060 значит «службы нет»)"

echo
echo "--- 3) COM-класс MMDeviceEnumerator (его отсутствие = нет звука, ошибка 80040154)"
if grep -aq 'bcde0395' "$W/system.reg"; then
    echo "    зарегистрирован в реестре:"
    grep -an -A2 'bcde0395' "$W/system.reg" | head -8 | sed 's/^/      /'
else
    echo "    НЕ зарегистрирован (32-битное представление Wow6432Node пусто) —"
    echo "    в логе игры будет: err:dsound:get_mmdevenum CoCreateInstance failed: 80040154"
    fail=1
fi
echo "    ответ реестра (HKLM\\Software\\Classes\\Wow6432Node\\CLSID\\$GUID):"
timeout 60 wine reg query "HKLM\\Software\\Classes\\Wow6432Node\\CLSID\\$GUID" 2>&1 \
    | grep -aviE 'actctx|^\s*$' | head -4 | sed 's/^/      /'

echo
echo "--- 4) файлы игры и библиотек"
for f in "$W/drive_c/windows/system32/rpcss.exe" "$W/drive_c/windows/syswow64/mmdevapi.dll"; do
    if [ -f "$f" ]; then echo "    есть: $f"; else echo "    НЕТ:  $f"; fail=1; fi
done

echo
echo "=============================================================="
if [ "$fail" -eq 0 ]; then
    echo "ВЕРДИКТ: профиль в порядке — служба RpcSs и класс звука на месте."
else
    echo "ВЕРДИКТ: профиль неполный. Запускайте:"
    echo "    ./fix-rpcss-service.sh $W"
    echo "    ./fix-mmdevenum.sh    $W"
    echo "и повторите диагностику."
fi
echo "=============================================================="
