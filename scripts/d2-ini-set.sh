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
