#!/bin/bash
# verify-launcher.sh — живая проверка: открывается ли окно игры и идёт ли звук.
# Запускает лаунчер так же, как пользователь, ждёт окно до 90 с, потом всё гасит.
# Использование: ./verify-launcher.sh [путь-к-лаунчеру]
set -u
export DISPLAY=:0

echo "=== 0) чистим остатки прошлых запусков ==="
timeout 25 wineserver -k 2>/dev/null; sleep 2
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
timeout 30 wineserver -k 2>/dev/null
echo "   игра: $(pgrep -x Discipl2.exe | wc -l) процессов"
