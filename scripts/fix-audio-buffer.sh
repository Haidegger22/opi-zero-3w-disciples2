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
