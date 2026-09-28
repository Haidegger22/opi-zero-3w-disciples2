#!/bin/bash
# fix-rpcss-service.sh — регистрация службы RpcSs в профиле Wine (arm64/Hangover).
#
# ЗАЧЕМ
#   Wine берёт список служб из реестра профиля: ключи пишет wineboot, обрабатывая
#   секции AddService из wine.inf ([DefaultInstall.ntarm64.Services]).
#   Если профиль создан «наполовину» (wineboot не дошёл до конца — типично для
#   Hangover на Zero 3W: он зависает на err:wgl:internal_context_create),
#   то ВСЕ службы, включая RpcSs, в system.reg отсутствуют. Тогда любой вызов RPC
#   печатает:
#       err:ole:start_rpcss Failed to open RpcSs service      (OpenService → 1060)
#   а COM-маршалинг падает:
#       err:ole:apartment_get_local_server_stream Failed: 0x80004002
#       err:ole:StdMarshalImpl_MarshalInterface Failed to create ifstub
#
#   Разница сообщений:
#     "Failed to open RpcSs service"  — службы НЕТ в реестре (этот скрипт лечит)
#     "Failed to start RpcSs service" — служба есть, но не поднялась (см. sc query/start)
#
# Использование:
#     ./fix-rpcss-service.sh [WINEPREFIX]     # по умолчанию ~/.wine-hg2
# Откат: wine reg delete "HKLM\System\CurrentControlSet\Services\RpcSs" /f
set -u

W="${1:-$HOME/.wine-hg2}"
export WINEPREFIX="$W"
export DISPLAY="${DISPLAY:-:0}"
export LD_LIBRARY_PATH="/usr/lib/aarch64-linux-gnu:/lib/aarch64-linux-gnu"
REG=/tmp/rpcss-service.reg

echo "=== профиль: $W"
[ -f "$W/system.reg" ] || { echo "   НЕТ профиля"; exit 1; }

echo
echo "=== 0) двоичный файл службы на месте?"
ls -la "$W/drive_c/windows/system32/rpcss.exe" 2>&1 | sed 's/^/   /'

echo
echo "=== 1) бэкап реестра"
STAMP=$(date +%Y%m%d-%H%M)
cp -a "$W/system.reg" "$W/system.reg.backup-$STAMP" && echo "   system.reg.backup-$STAMP"

echo
echo "=== 2) состояние ДО (sc query)"
timeout 60 wine sc query RpcSs 2>&1 | grep -aviE 'actctx|^\s*$' | head -6 | sed 's/^/   /'
echo "   (ошибка 1060 = «служба не существует» — это наш случай)"

echo
echo "=== 3) прописываю службу в реестр"
cat > "$REG" <<'REGEOF'
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\RpcSs]
"Type"=dword:00000010
"Start"=dword:00000003
"ImagePath"="C:\\windows\\system32\\rpcss.exe"
"ObjectName"="LocalSystem"
"DisplayName"="Remote Procedure Call (RPC)"
"Description"="RPC service"
"ErrorControl"=dword:00000001
REGEOF
wine reg import "$REG" 2>&1 | grep -aviE 'actctx|^\s*$' | sed 's/^/   /'

echo
echo "=== 4) перезапуск диспетчера служб (SCM кэширует базу служб на старте)"
timeout 30 wineserver -k 2>/dev/null
sleep 2

echo
echo "=== 5) проверка"
timeout 60 wine sc query RpcSs 2>&1 | grep -aviE 'actctx|^\s*$' | sed 's/^/   /'
echo "   --- старт службы:"
timeout 60 wine sc start RpcSs 2>&1 | grep -aviE 'actctx|^\s*$' | sed 's/^/   /'

echo
echo "=== 6) ключ в system.reg (пишется как ControlSet001 — CurrentControlSet это ссылка)"
grep -an -A9 'Services\\\\RpcSs' "$W/system.reg" 2>/dev/null | head -14 | sed 's/^/   /'

echo
if timeout 60 wine sc query RpcSs 2>&1 | grep -q 'SERVICE_NAME'; then
    echo "=== ИТОГ: служба RpcSs зарегистрирована, SCM её видит ✔"
    echo "    STATE: 4 RUNNING в ответе sc start = стартует нормально"
else
    echo "=== ИТОГ: НЕ зарегистрирована — смотрите вывод выше"
    exit 1
fi
