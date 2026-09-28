#!/bin/bash
# fix-mmdevenum.sh — принудительная регистрация COM-класса MMDeviceEnumerator
# в профиле Wine на arm64 (Hangover).
#
# ПРОБЛЕМА, которую это лечит
#   Игра (32-битный PE) вызывает CoCreateInstance(CLSID_MMDeviceEnumerator) из dsound
#   ДО того, как загружена библиотека syswow64\mmdevapi.dll. Wine регистрирует
#   встроенные COM-классы не из wine.inf, а из ресурса WINE_REGISTRY ЭТОЙ ЖЕ
#   библиотеки — то есть только в момент её загрузки. Если класс ещё не прописан,
#   вызов возвращает REGDB_E_CLASSNOTREG (0x80040154) и звука нет:
#       err:dsound:get_mmdevenum CoCreateInstance failed: 80040154
#       warn:dsound:DirectSoundDevice_Initialize invalid parameter: lpcGUID
#
#   Лечение — прописать класс руками. Проверено на Orange Pi Zero 3W:
#   без ключа ошибка 80040154 воспроизводится; после регистрации исчезает.
#
# Использование:
#     ./fix-mmdevenum.sh [WINEPREFIX]      # по умолчанию ~/.wine-hg2
# Откат: wine reg delete "HKLM\Software\Classes\Wow6432Node\CLSID\<GUID>" /f
set -u

W="${1:-$HOME/.wine-hg2}"
GUID='{bcde0395-e52f-467c-8e3d-c4579291692e}'
VIEW='Wow6432Node'          # 32-битное представление реестра (игра — 32-битная)
KEY="HKLM\\Software\\Classes\\${VIEW}\\CLSID\\${GUID}"
REG=/tmp/mmdevenum-fix.reg

export WINEPREFIX="$W"
export DISPLAY="${DISPLAY:-:0}"
# На Zero 3W вендорские libEGL/libGLESv2 (PowerVR) ломают создание GL-контекста
# у Wine — подставляем системные библиотеки.
export LD_LIBRARY_PATH="/usr/lib/aarch64-linux-gnu:/lib/aarch64-linux-gnu"

echo "=== профиль: $W"
[ -f "$W/system.reg" ] || { echo "   НЕТ профиля — неверный путь"; exit 1; }

echo "=== 1) бэкап реестра профиля"
STAMP=$(date +%Y%m%d-%H%M)
cp -a "$W/system.reg" "$W/system.reg.backup-$STAMP" && echo "   system.reg.backup-$STAMP"

echo
echo "=== 2) состояние ДО"
if grep -aq 'bcde0395' "$W/system.reg"; then
    echo "   класс УЖЕ прописан:"
    grep -an -A3 'bcde0395' "$W/system.reg" | head -8 | sed 's/^/      /'
else
    echo "   класса нет (это и есть причина отсутствия звука)"
fi

echo
echo "=== 3) регистрирую класс"
cat > "$REG" <<'REGEOF'
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\Software\Classes\Wow6432Node\CLSID\{bcde0395-e52f-467c-8e3d-c4579291692e}]
@="MMDeviceEnumerator Object"

[HKEY_LOCAL_MACHINE\Software\Classes\Wow6432Node\CLSID\{bcde0395-e52f-467c-8e3d-c4579291692e}\InprocServer32]
@="C:\\windows\\syswow64\\mmdevapi.dll"
"ThreadingModel"="Both"
REGEOF
wine reg import "$REG" 2>&1 | grep -aviE 'actctx|^\s*$' | sed 's/^/   /'
echo "   (пустой вывод = импорт без ошибок)"

echo
echo "=== 4) проверка через реестр (нужна пауза: wineserver сбрасывает реестр на диск)"
timeout -s KILL 30 wineserver -w 2>/dev/null
wine reg query "$KEY" 2>&1 | grep -aviE 'actctx|^\s*$' | sed 's/^/   /'
wine reg query "${KEY}\\InprocServer32" 2>&1 | grep -aviE 'actctx|^\s*$' | sed 's/^/   /'

echo
if grep -aq 'bcde0395' "$W/system.reg"; then
    echo "=== ИТОГ: класс зарегистрирован ✔"
    echo "    проверка живым запуском: cd в каталог игры && WINEDEBUG=+dsound wine Discipl2.exe"
    echo "    в логе не должно быть 'get_mmdevenum CoCreateInstance failed'"
else
    echo "=== ИТОГ: НЕ зарегистрирован — смотрите ошибки выше"
    exit 1
fi
