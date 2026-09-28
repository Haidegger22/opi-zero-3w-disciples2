# INSTALL — Disciples II: Gold (русская версия) на Orange Pi Zero 3W

Для кого: **Orange Pi Zero 3W** (Allwinner A733), **Debian 13 «Trixie»**, X11 + MATE,
дисплей 1024×600. Wine — дистрибутивный **Hangover** (arm64-сборка Wine 11.x), **без box64**.

Что получится: игра запускается ярлыком, открывает окно «Disciples II» и играет звуком
через PipeWire. Все команды ниже можно копировать в терминал по порядку.

## Шаг 1. Зависимости

```bash
sudo apt update
sudo apt install -y hangover-wine xdotool innoextract pactl
# проверка: должна печататься версия вида «wine-11.16 (Hangover)»
wine --version
```

`xdotool` нужен только для проверки окна, `innoextract` — если игру распаковываете сами
(GOG-инсталляторы распаковываются `innoextract`, а **не** запуском `.exe` в Wine).

## Шаг 2. Клонировать репозиторий

```bash
git clone https://github.com/Haidegger22/opi-zero-3w-disciples2.git ~/opi-zero-3w-disciples2
cd ~/opi-zero-3w-disciples2
```

## Шаг 3. Скрипты — в `~/.local/bin`

```bash
mkdir -p ~/.local/bin
install -m755 scripts/disc2-zero.sh scripts/fix-mmdevenum.sh \
              scripts/fix-rpcss-service.sh scripts/diagnose-wine-prefix.sh \
              scripts/verify-launcher.sh scripts/d2-ini-set.sh \
              scripts/set-resolution.sh scripts/verify-game-state.sh ~/.local/bin/
ls -l ~/.local/bin/ | grep -E 'disc2|mmdev|rpcss|diagnose|verify'
```

## Шаг 4. Сама игра

Положите распакованную игру так, чтобы файл `Discipl2.exe` лежал в `~/d2-ru-pack/app`:

```bash
# вариант А: распаковать GOG-инсталлятор (файл setup_disciples2_*.exe)
innoextract -e -d ~/d2-ru-pack/app ~/setup_disciples2_gold_*.exe
ls ~/d2-ru-pack/app/Discipl2.exe
```

Если игра уже лежит в другом каталоге — просто задайте `GAME_DIR` при запуске
(см. шаг 8), путь `~/d2-ru-pack/app` не обязателен.

## Шаг 5. Профиль Wine и его лечение (главный шаг)

```bash
export WINEPREFIX=$HOME/.wine-hg2

# 5.1 создать профиль (wineboot на этой плате может «зависнуть» — это ожидаемо,
#     прерываем его и лечим реестр вручную)
timeout -s KILL 240 wineboot -u || echo "wineboot не завершился — это известная беда, продолжаем"
timeout 30 wineserver -k

# 5.2 звук: зарегистрировать COM-класс MMDeviceEnumerator
~/.local/bin/fix-mmdevenum.sh "$WINEPREFIX"

# 5.3 RPC: зарегистрировать службу RpcSs
~/.local/bin/fix-rpcss-service.sh "$WINEPREFIX"
```

В конце каждого скрипта должно быть `ИТОГ: класс зарегистрирован ✔` и
`ИТОГ: служба RpcSs зарегистрирована, SCM её видит ✔`.

## Шаг 6. Диагностика

```bash
~/.local/bin/diagnose-wine-prefix.sh "$HOME/.wine-hg2"
```

Ожидаемый вердикт — `ВЕРДИКТ: профиль в порядке`. Пока он не такой — игру запускать
бессмысленно: либо не будет звука, либо посыпятся ошибки OLE/RPC.

## Шаг 7. Ярлык на рабочем столе и в меню

```bash
mkdir -p ~/.local/share/applications ~/.local/share/icons ~/Desktop
cp desktop/disciples2.desktop ~/.local/share/applications/
# подставить ДОМАШНИЙ каталог читателя вместо /home/orangepi
sed -i "s|/home/orangepi|$HOME|g" ~/.local/share/applications/disciples2.desktop
cp ~/.local/share/applications/disciples2.desktop ~/Desktop/
chmod +x ~/Desktop/disciples2.desktop
```

Иконку возьмите из самой игры (она там есть):

```bash
cp ~/d2-ru-pack/app/Disciples2RotE.ico ~/.local/share/icons/disciples2.png 2>/dev/null || true
```

## Шаг 8. Запуск и проверка

```bash
disc2-zero.sh                     # обычный запуск
# если игра лежит не в ~/d2-ru-pack/app:
GAME_DIR=/путь/к/игре disc2-zero.sh
```

Проверка «как у пользователя» (окно + звук + ошибки в логе):

```bash
~/.local/bin/verify-launcher.sh
```

Ожидаемое: `окно=117440513` и заголовок `Disciples II` в первые 15–30 секунд,
в `pactl list sink-inputs` — поток `Disciples II v3.01`, в логе — `всего err-строк: 0`.

## Шаг 9. Звук: буфер 1024 кадра (лечит хрипы и «песок»)

```bash
~/.local/bin/fix-audio-buffer.sh
```

Скрипт поднимает буфер звукового графа с 2,7 мс до 21 мс и закрепляет это службой пользователя,
чтобы настройка возвращалась после перезагрузки. В конце должно быть
`ИТОГ: буфер 1024 держится и возвращается после перезапуска ✔`.
Откат: `systemctl --user disable --now audio-buffer.service`.

## Шаг 10. Полный экран

```bash
~/.local/bin/set-fullscreen.sh            # весь экран
~/.local/bin/set-fullscreen.sh windowed   # вернуть окно
~/.local/bin/set-fullscreen.sh test       # включить и сразу проверить геометрию
```

Скрипт правит ключ `DisplayMode` в `Disciple.ini` (в самом файле подсказка: `0=full-screen,
1=windowed`), рядом остаётся бэкап `Disciple.ini.backup-ГГГГММДД-ЧЧММ`.

## Шаг 11. Разрешение, темп и настройки игры (`Disciple.ini`)

```bash
~/.local/bin/verify-game-state.sh          # что сейчас: игра, окно, настройки, бэкапы (только чтение)
~/.local/bin/set-resolution.sh 1024 600    # рисовать по размеру экрана (нужен HD=1)
~/.local/bin/d2-ini-set.sh BattleSpeed 1   # скорость боя: 1 медленно … 4 мгновенно
~/.local/bin/d2-ini-set.sh SpeedEnabled 0  # выключить ускоритель анимации обёртки
```

Сборка по умолчанию идёт с `DisplayWidth=800`, а экран платы — 1024×600, то есть кадр
растягивается. `set-resolution.sh 1024 600` ставит размер экрана: окно становится ровно по
режиму (`xdotool getwindowgeometry` → `WIDTH=1024 HEIGHT=600`), а кадр заметно детальнее
(PNG-скриншот того же экрана вырос с 416 КБ до 889 КБ).

Если бой или анимация кажутся ускоренными — виноват не `BattleSpeed`, а **ускоритель обёртки**:
`SpeedEnabled=1` вместе с `GameSpeed=5` даёт анимацию в 1,5× быстрее обычной. Разбор этого случая
и полный справочник параметров русской обёртки (`C4dll-R.dll`) — в `docs/WRAPPER-AND-GAME-SETTINGS.md`.

Важно: `Disciple.ini` в кодировке **cp1251**, поэтому правьте его скриптом `d2-ini-set.sh`
(он закрывает игру, делает бэкап и показывает диф), а не `sed`. Игра **перезаписывает** этот файл
своими настройками — правки делайте при закрытой игре и сверяйте диф с бэкапом: пустой диф
означает, что вы поменяли то, что уже стояло.

## Важно

- Вывод звука на этой плате: **Bluetooth-колонка** (A2DP, кодек SBC) либо **HDMI**
  (ALSA-карта `allwinner-hdmi`). Аналогового выхода нет.
- `LD_LIBRARY_PATH` внутри лаунчера переопределяется на системный намеренно: вендорские
  `libEGL/libGLESv2` от PowerVR ломают создание GL-контекста у Wine.
- Скрипты **меняют реестр профиля Wine** (с бэкапом `system.reg.backup-ГГГГММДД-ЧЧММ`
  рядом с профилем). Систему они не трогают.
- `wineboot -u` на этой плате не завершается — профиль остаётся без служб и части
  реестровых веток. Скрипты дописывают то, что нужно игре, но остальные службы
  (`MountMgr`, `PlugPlay`, `Eventlog`, …) так и останутся отсутствующими.
- После любого `wine reg import` запускайте `wineserver -w` (или `-k`), иначе чтение
  реестра вернёт старое состояние — Wine держит реестр в памяти.

## Откат

```bash
# убрать правки реестра
export WINEPREFIX=$HOME/.wine-hg2
wine reg delete 'HKLM\Software\Classes\Wow6432Node\CLSID\{bcde0395-e52f-467c-8e3d-c4579291692e}' /f
wine reg delete 'HKLM\System\CurrentControlSet\Services\RpcSs' /f
# или вернуть бэкап целиком:
cp "$WINEPREFIX"/system.reg.backup-ГГГГММДД-ЧЧММ "$WINEPREFIX"/system.reg

# убрать ярлыки и скрипты
rm -f ~/Desktop/disciples2.desktop ~/.local/share/applications/disciples2.desktop
rm -f ~/.local/bin/{disc2-zero,fix-mmdevenum,fix-rpcss-service,diagnose-wine-prefix,verify-launcher,d2-ini-set,set-resolution,verify-game-state}.sh
```

---

## Полный код файлов (установка без git)

Ниже — те же файлы целиком, если удобнее создавать их руками (например, без git).
Копируйте блоки по порядку; делимитер `'SCRIPT_EOF'` в кавычках обязателен.

### 1. Лаунчер игры

```bash
mkdir -p $(dirname $HOME/.local/bin/disc2-zero.sh)
cat > $HOME/.local/bin/disc2-zero.sh << 'SCRIPT_EOF'
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
timeout -s KILL 25 wineserver -k 2>/dev/null; sleep 2
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
SCRIPT_EOF
chmod +x $HOME/.local/bin/disc2-zero.sh 2>/dev/null || true
```

### 2. Регистрация COM-класса MMDeviceEnumerator (звук)

```bash
mkdir -p $(dirname $HOME/.local/bin/fix-mmdevenum.sh)
cat > $HOME/.local/bin/fix-mmdevenum.sh << 'SCRIPT_EOF'
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
SCRIPT_EOF
chmod +x $HOME/.local/bin/fix-mmdevenum.sh 2>/dev/null || true
```

### 3. Регистрация службы RpcSs (RPC/OLE)

```bash
mkdir -p $(dirname $HOME/.local/bin/fix-rpcss-service.sh)
cat > $HOME/.local/bin/fix-rpcss-service.sh << 'SCRIPT_EOF'
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
timeout -s KILL 60 wine sc query RpcSs 2>&1 | grep -aviE 'actctx|^\s*$' | head -6 | sed 's/^/   /'
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
timeout -s KILL 30 wineserver -k 2>/dev/null
sleep 2

echo
echo "=== 5) проверка"
timeout -s KILL 60 wine sc query RpcSs 2>&1 | grep -aviE 'actctx|^\s*$' | sed 's/^/   /'
echo "   --- старт службы:"
timeout -s KILL 60 wine sc start RpcSs 2>&1 | grep -aviE 'actctx|^\s*$' | sed 's/^/   /'

echo
echo "=== 6) ключ в system.reg (пишется как ControlSet001 — CurrentControlSet это ссылка)"
grep -an -A9 'Services\\\\RpcSs' "$W/system.reg" 2>/dev/null | head -14 | sed 's/^/   /'

echo
if timeout -s KILL 60 wine sc query RpcSs 2>&1 | grep -q 'SERVICE_NAME'; then
    echo "=== ИТОГ: служба RpcSs зарегистрирована, SCM её видит ✔"
    echo "    STATE: 4 RUNNING в ответе sc start = стартует нормально"
else
    echo "=== ИТОГ: НЕ зарегистрирована — смотрите вывод выше"
    exit 1
fi
SCRIPT_EOF
chmod +x $HOME/.local/bin/fix-rpcss-service.sh 2>/dev/null || true
```

### 4. Диагностика профиля Wine

```bash
mkdir -p $(dirname $HOME/.local/bin/diagnose-wine-prefix.sh)
cat > $HOME/.local/bin/diagnose-wine-prefix.sh << 'SCRIPT_EOF'
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
timeout -s KILL 60 wine sc query RpcSs 2>&1 | grep -aviE 'actctx|^\s*$' | head -6 | sed 's/^/      /'
echo "      (exit-код sc: $(timeout -s KILL 60 wine sc query RpcSs >/dev/null 2>&1; echo $?) — 1060 значит «службы нет»)"

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
timeout -s KILL 60 wine reg query "HKLM\\Software\\Classes\\Wow6432Node\\CLSID\\$GUID" 2>&1 \
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
SCRIPT_EOF
chmod +x $HOME/.local/bin/diagnose-wine-prefix.sh 2>/dev/null || true
```

### 5. Проверка запуска (окно + звук)

```bash
mkdir -p $(dirname $HOME/.local/bin/verify-launcher.sh)
cat > $HOME/.local/bin/verify-launcher.sh << 'SCRIPT_EOF'
#!/bin/bash
# verify-launcher.sh — живая проверка: открывается ли окно игры и идёт ли звук.
# Запускает лаунчер так же, как пользователь, ждёт окно до 90 с, потом всё гасит.
# Использование: ./verify-launcher.sh [путь-к-лаунчеру]
set -u
export DISPLAY=:0

echo "=== 0) чистим остатки прошлых запусков ==="
timeout -s KILL 25 wineserver -k 2>/dev/null; sleep 2
pkill -x Discipl2.exe 2>/dev/null; sleep 1
echo "   Discipl2.exe: $(pgrep -x Discipl2.exe | wc -l)  wineserver: $(pgrep -x wineserver | wc -l)"

echo
LAUNCHER="${1:-$HOME/.local/bin/disc2-zero.sh}"
echo "=== 1) запуск лаунчера: $LAUNCHER"
nohup "$LAUNCHER" > /tmp/verify-launch.log 2>&1 &
sleep 5
echo "   стартовал, ждём окно до 90 с"
for t in 15 30 45 60 75 90; do
  sleep 15
  W=$(xdotool search --name "Disciples" 2>/dev/null | head -1)
  P=$(pgrep -x Discipl2.exe 2>/dev/null | head -1)
  echo "   ${t} с: процесс=${P:-нет}  окно=${W:-нет}"
  if [ -n "$W" ]; then break; fi
done

echo
echo "=== 2) окна с 'Disciples' в заголовке ==="
for id in $(xdotool search --name "Disciples" 2>/dev/null | head -4); do
  echo "   id=$id  имя='$(xdotool getwindowname "$id" 2>/dev/null)'  геометрия=$(xdotool getwindowgeometry --shell "$id" 2>/dev/null | tr '\n' ' ')"
done

echo
echo "=== 3) звуковой поток в PipeWire/Pulse ==="
pactl list sink-inputs 2>/dev/null | grep -E "application.name|Volume:" | head -4 | sed 's/^/   /'

echo
echo "=== 4) ошибки в логе запуска (топ) ==="
echo "   всего err-строк: $(grep -ac 'err:' /tmp/verify-launch.log 2>/dev/null)"
grep -a 'err:' /tmp/verify-launch.log 2>/dev/null | sed 's/^[0-9a-f]*://' | sort | uniq -c | sort -rn | head -8 | sed 's/^/   /'

echo
echo "=== 5) закрываю ==="
pkill -x Discipl2.exe 2>/dev/null; sleep 2
timeout -s KILL 30 wineserver -k 2>/dev/null
echo "   игра: $(pgrep -x Discipl2.exe | wc -l) процессов"
SCRIPT_EOF
chmod +x $HOME/.local/bin/verify-launcher.sh 2>/dev/null || true
```

### 6. Постоянный буфер звука 1024 кадра (лечит хрипы)

```bash
mkdir -p $(dirname $HOME/.local/bin/fix-audio-buffer.sh)
cat > $HOME/.local/bin/fix-audio-buffer.sh << 'SCRIPT_EOF'
#!/bin/bash
# fix-audio-buffer.sh — постоянный буфер звука 1024 кадра (≈21 мс) для Zero 3W.
#
# ПРОБЛЕМА
#   PipeWire отдаёт Bluetooth-выводу период 128 кадров (≈2,7 мс — один SBC-кадр).
#   Под нагрузкой (Wine + программный рендеринг llvmpipe) звук не успевает заполнять
#   такой мелкий буфер: слышны хрипы, шипение, «песок», рывки.
#   Wine к тому же сам просит низкую задержку — поэтому одного default.clock.quantum
#   НЕ хватает: он только «по умолчанию», клиент может попросить меньше.
#
# РЕШЕНИЕ
#   Жёсткий force-quantum=1024 (перебивает запросы приложений) + служба пользователя,
#   чтобы настройка возвращалась после каждой перезагрузки и рестарта PipeWire.
#   Проверено на слух владельцем 28.09.2026: «оставляем, мне нравится».
#
# Использование: ./fix-audio-buffer.sh [квант]     # по умолчанию 1024
# Откат: systemctl --user disable --now audio-buffer.service && rm ~/.config/systemd/user/audio-buffer.service
set -u

Q="${1:-1024}"
UNIT_DIR="$HOME/.config/systemd/user"
UNIT="$UNIT_DIR/audio-buffer.service"

echo "=== 1) ставлю буфер на лету (сразу слышно, без перезагрузки) ==="
pw-metadata -n settings 0 clock.force-quantum "$Q" 2>&1 | tail -1 | sed 's/^/   /'
sleep 1
pw-metadata -n settings 2>/dev/null | grep -a 'force-quantum' | sed 's/^/   сейчас: /'

echo
echo "=== 2) создаю службу пользователя, чтобы настройка жила после перезагрузки ==="
mkdir -p "$UNIT_DIR"
cat > "$UNIT" <<EOF
[Unit]
Description=Force PipeWire quantum $Q (звук BT-колонки, Orange Pi Zero 3W)
After=pipewire.service wireplumber.service
PartOf=pipewire.service
Requisite=pipewire.service

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'sleep 3; exec /usr/bin/pw-metadata -n settings 0 clock.force-quantum $Q'
RemainAfterExit=yes

[Install]
WantedBy=pipewire.service
EOF
echo "   создан: $UNIT"

echo
echo "=== 3) включаю ==="
systemctl --user daemon-reload
systemctl --user enable audio-buffer.service 2>&1 | tail -1 | sed 's/^/   /'
systemctl --user restart audio-buffer.service 2>&1 | tail -1 | sed 's/^/   /'
sleep 5
echo "   служба: $(systemctl --user is-active audio-buffer.service) / $(systemctl --user is-enabled audio-buffer.service)"

echo
echo "=== 4) проверка: перезапускаю PipeWire — буфер должен вернуться сам ==="
systemctl --user restart pipewire pipewire-pulse wireplumber
sleep 7
V=$(pw-metadata -n settings 2>/dev/null | grep -a 'force-quantum')
echo "   $V"
if echo "$V" | grep -q "value:'$Q'"; then
    echo "=== ИТОГ: буфер $Q держится и возвращается после перезапуска ✔"
    echo "    Откат: systemctl --user disable --now audio-buffer.service; rm -f $UNIT"
else
    echo "=== ИТОГ: не применилось — проверьте вывод выше"
    exit 1
fi
SCRIPT_EOF
chmod +x $HOME/.local/bin/fix-audio-buffer.sh 2>/dev/null || true
```

### 7. Полный экран игры / возврат в окно

```bash
mkdir -p $(dirname $HOME/.local/bin/set-fullscreen.sh)
cat > $HOME/.local/bin/set-fullscreen.sh << 'SCRIPT_EOF'
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
SCRIPT_EOF
chmod +x $HOME/.local/bin/set-fullscreen.sh 2>/dev/null || true
```

### 8. Правка одного параметра Disciple.ini (бэкап + диф)

```bash
mkdir -p $(dirname $HOME/.local/bin/d2-ini-set.sh)
cat > $HOME/.local/bin/d2-ini-set.sh << 'SCRIPT_EOF'
#!/bin/bash
# d2-ini-set.sh <КЛЮЧ> <ЗНАЧЕНИЕ> — правка ОДНОГО параметра в Disciple.ini.
#
# Зачем именно так, а не sed/правкой руками:
#   * файл в кодировке cp1251 — sed/редакторы портят кириллицу (имя игрока, локаль);
#   * игра перезаписывает Disciple.ini своими настройками, поэтому нужен бэкап и диф:
#     пустой диф = вы правите то, что уже стоит (см. docs/WRAPPER-AND-GAME-SETTINGS.md);
#   * правка на работающей игре может не примениться.
#
# Примеры:
#   ./d2-ini-set.sh BattleSpeed 2        # скорость боя: 1 медленно … 4 мгновенно
#   ./d2-ini-set.sh SpeedEnabled 0      # ускоритель анимации обёртки выключить
#   ./d2-ini-set.sh DisplayWidth 1024
set -u
GAME="${GAME_DIR:-$HOME/d2-ru-pack/app}"
INI="$GAME/Disciple.ini"
KEY="${1:?нужен ключ, например BattleSpeed}"
VAL="${2:?нужно значение, например 1}"

[ -f "$INI" ] || { echo "нет файла $INI (задайте GAME_DIR)"; exit 1; }

echo "=== 0) игра должна быть закрыта ==="
if pgrep -x Discipl2.exe >/dev/null 2>&1; then
    echo "   игра работает — закрываю, иначе правка не применится"
    pkill -x Discipl2.exe 2>/dev/null; sleep 2
    WINEPREFIX="${WINEPREFIX:-$HOME/.wine-hg2}" timeout -s KILL 25 wineserver -k 2>/dev/null; sleep 1
fi
echo "   процессов игры: $(pgrep -xc Discipl2.exe 2>/dev/null | head -1)"

STAMP=$(date +%Y%m%d-%H%M%S-%3N)   # миллисекунды: два запуска в одну секунду не затирают бэкап
cp -a "$INI" "$INI.backup-$STAMP" && echo "=== 1) бэкап: $INI.backup-$STAMP"

echo "=== 2) было / стало ($KEY) ==="
iconv -f cp1251 -t utf-8 "$INI" | grep -aiE "^$KEY=" | tr -d '\r' | sed 's/^/   было:  /'
python3 - "$INI" "$KEY" "$VAL" <<'PY'
import io, re, sys
p, k, v = sys.argv[1], sys.argv[2], sys.argv[3]
raw = io.open(p, encoding="cp1251", errors="surrogateescape", newline="").read()
new, n = re.subn(r'(?mi)^' + re.escape(k) + r'\s*=\s*[^\r\n]*', k + "=" + v, raw, count=1)
if n == 0:
    print("   ВНИМАНИЕ: ключ не найден, файл не изменён")
else:
    io.open(p, "w", encoding="cp1251", errors="surrogateescape", newline="").write(new)
PY
iconv -f cp1251 -t utf-8 "$INI" | grep -aiE "^$KEY=" | tr -d '\r' | sed 's/^/   стало: /'

echo "=== 3) все отличия от бэкапа ==="
diff <(iconv -f cp1251 -t utf-8 "$INI.backup-$STAMP" | tr -d '\r') \
     <(iconv -f cp1251 -t utf-8 "$INI" | tr -d '\r') | sed 's/^/   /'
echo "   откат: cp $INI.backup-$STAMP $INI"
SCRIPT_EOF
chmod +x $HOME/.local/bin/d2-ini-set.sh 2>/dev/null || true
```

### 9. Разрешение картинки игры (DisplayWidth/DisplayHeight)

```bash
mkdir -p $(dirname $HOME/.local/bin/set-resolution.sh)
cat > $HOME/.local/bin/set-resolution.sh << 'SCRIPT_EOF'
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
SCRIPT_EOF
chmod +x $HOME/.local/bin/set-resolution.sh 2>/dev/null || true
```

### 10. Снимок состояния игры: окно, настройки, бэкапы

```bash
mkdir -p $(dirname $HOME/.local/bin/verify-game-state.sh)
cat > $HOME/.local/bin/verify-game-state.sh << 'SCRIPT_EOF'
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
SCRIPT_EOF
chmod +x $HOME/.local/bin/verify-game-state.sh 2>/dev/null || true
```

### 11. То же, что fix-mmdevenum, но файлом .reg

```bash
mkdir -p $(dirname $HOME/mmdevenum-wow6432.reg)
cat > $HOME/mmdevenum-wow6432.reg << 'SCRIPT_EOF'
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\Software\Classes\Wow6432Node\CLSID\{bcde0395-e52f-467c-8e3d-c4579291692e}]
@="MMDeviceEnumerator Object"

[HKEY_LOCAL_MACHINE\Software\Classes\Wow6432Node\CLSID\{bcde0395-e52f-467c-8e3d-c4579291692e}\InprocServer32]
@="C:\\windows\\syswow64\\mmdevapi.dll"
"ThreadingModel"="Both"
SCRIPT_EOF
chmod +x $HOME/mmdevenum-wow6432.reg 2>/dev/null || true
```

### 12. То же, что fix-rpcss-service, но файлом .reg

```bash
mkdir -p $(dirname $HOME/rpcss-service.reg)
cat > $HOME/rpcss-service.reg << 'SCRIPT_EOF'
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\RpcSs]
"Type"=dword:00000010
"Start"=dword:00000003
"ImagePath"="C:\\windows\\system32\\rpcss.exe"
"ObjectName"="LocalSystem"
"DisplayName"="Remote Procedure Call (RPC)"
"Description"="RPC service"
"ErrorControl"=dword:00000001
SCRIPT_EOF
chmod +x $HOME/rpcss-service.reg 2>/dev/null || true
```

### 13. Ярлык

```bash
mkdir -p $(dirname $HOME/.local/share/applications/disciples2.desktop)
cat > $HOME/.local/share/applications/disciples2.desktop << 'SCRIPT_EOF'
[Desktop Entry]
Type=Application
Version=1.0
Name=Disciples II: Gold (русская версия)
Name[en]=Disciples II: Gold (Russian)
Comment=Запуск Disciples II: Gold через Wine (Hangover) на Orange Pi Zero 3W
Comment[en]=Launch Disciples II: Gold with Wine (Hangover) on Orange Pi Zero 3W
Exec=/home/orangepi/.local/bin/disc2-zero.sh
Icon=/home/orangepi/.local/share/icons/disciples2.png
Terminal=false
Categories=Game;StrategyGame;
Keywords=disciples;strategy;wine;
StartupNotify=true
SCRIPT_EOF
chmod +x $HOME/.local/share/applications/disciples2.desktop 2>/dev/null || true
```

