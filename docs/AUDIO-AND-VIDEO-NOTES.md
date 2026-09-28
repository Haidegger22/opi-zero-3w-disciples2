# Звук и видео на Zero 3W: что настроено и что проверено

Замеры и правки от 28.09.2026, Orange Pi Zero 3W, Debian 13 «Trixie», MATE/X11, экран 1024×600,
Wine 11.16 (Hangover), звук — Bluetooth-колонка `HABBARMERS` (A2DP).

---

## 1. Звук: буфер 1024 кадра (≈21 мс) — жёстко, force-quantum

### Симптом
В игре слышны хрипы, шипение, «песок», рывки звука. При этом ошибок звука в логе Wine нет,
`dsound` инициализируется чисто, `get_mmdevenum`/`mmdevapi` — без ошибок, поток в PipeWire виден:
`application.name = "Disciples II v3.01"`, `float32le 2ch 48000 Hz`.

### Что показал замер
```
pw-top во время игры:
  R  45   128  48000  ...  ERR=0   S16LE 2 48000  bluez_output.12_11_76_F6_3E_92.1
```
Период BT-узла — **128 кадров ≈ 2,7 мс** (это ровно один SBC-кадр). Wine просит низкую задержку,
поэтому граф собирается с таким мелким периодом, и на плате, где GPU работает программно
(llvmpipe, Xorg под 84 % CPU), звуковой поток не успевает заполнять буфер.

### Что сделано
```bash
pw-metadata -n settings 0 clock.force-quantum 1024      # на лету, 21 мс вместо 2,7 мс
```
Плюс служба пользователя `audio-buffer.service`, чтобы настройка возвращалась после перезагрузки
и после любого рестарта PipeWire (проверено: после `systemctl --user restart pipewire` значение
снова 1024).

**Важно, что именно `force-quantum`, а не `quantum`.** `default.clock.quantum` — лишь значение
по умолчанию, и приложение может попросить меньше; Wine этим и пользуется. `force-quantum`
перебивает запросы клиентов. По этой же причине не сработал вариант с файлом
`~/.config/pipewire/pipewire.conf.d/99-buffer.conf`: ключ `default.clock.force-quantum` в
`context.properties` этой версией PipeWire (1.4.2) не читается — проверено, после рестарта
значение оставалось `0`. Также не подошёл `wpctl settings clock.force-quantum` — WirePlumber
такой настройки не знает (отвечает `Failed to set setting`).

Итог: **1024 кадра, закреплено службой**, владелец проверил на слух — «оставляем, мне нравится».

### Что искали и НЕ при чём
- **Буфер не был причиной щелчков сам по себе** — но именно он давал хрипы под нагрузкой.
- **SBC-XQ недостижим на этой сборке.** Колонка заявляет только SBC (A2DP-эндпоинт: `Codec = 0`,
  capability `FF FF 02 27` — все режимы, максимальный bitpool 39). Конфиг
  `~/.config/wireplumber/wireplumber.conf.d/51-bluez-quality.conf` до плагина **доходит**
  (доказано: временный заведомо неверный `bluez5.codecs` дал в журнале
  `spa.bluez5: property bluez5.codecs '…' is not an array`), но вариант `sbc_xq` в списке
  эндпоинтов не регистрируется ни при `[ sbc_xq sbc ]`, ни при `[ sbc_xq ]`, и параметры
  транспорта не меняются (`Configuration = 17 21 2 39` до и после). Правка удалена как
  не дающая эффекта.
- aptX/AAC/LDAC недоступны: колонка их не заявляет, AAC не собран в BlueZ этой системы
  (в списке эндпоинтов есть sbc, aptx, aptx_hd, ldac, faststream, opus, opus_g).
- Громкость вывода владелец держит на 25–38 %, это его выбор — скрипт её не трогает.

---

## 2. Видео: полный экран включается ключом в файле игры

Файл игры `Disciple.ini` (кодировка CP1251, CRLF) сам подсказывает:

```ini
[Disciple]
; 0=full-screen, 1 = windowed
DisplayMode=1        ; ← 1 = окно, 0 = полный экран
DisplaySize=0
RefreshRate=0
```

**Проверено:** при `DisplayMode=0` окно игры занимает весь экран:

```
xdotool getwindowgeometry:  X=0 Y=0 WIDTH=1024 HEIGHT=600
xprop _NET_WM_STATE:        _NET_WM_STATE_FULLSCREEN, _NET_WM_STATE_FOCUSED
xrandr:                     HDMI-1 connected primary 1024x600+0+0
```

Переключение — `scripts/set-fullscreen.sh` (по умолчанию полный экран, `windowed` — вернуть окно,
`test` — включить и сразу проверить геометрию). Скрипт делает бэкап `Disciple.ini.backup-ГГГГММДД-ЧЧММ`
рядом с файлом; откат — скопировать бэкап обратно.

`DisplaySize` и `RefreshRate` оставлены как были: панель умеет только 1024×600 (единственный режим
в `xrandr`), а игра 2002 года рассчитана на 800×600 — масштаб она подбирает сама, картинка
растягивается на весь экран без чёрных полей.

---

## 3. Наблюдение на будущее: ложные ошибки OLE в логе

В каждом запуске игры в логе есть строки, **не влияющие на игру**:

```
err:commdlg:DllMain failed to create activation context, last error 14001
err:ole:StdMarshalImpl_MarshalInterface Failed to create ifstub, hr 0x80004002
err:ole:CoMarshalInterface Failed to marshal the interface {6d5140c1-7436-11ce-8034-00aa006009fa}
err:ole:com_get_class_object class {2fe8f810-b2a5-11d0-a787-0000f803abfc} not registered
```

- `{6d5140c1-…}` — это `IID_IServiceProvider` (`/usr/include/wine/windows/servprov.h`), маршалинг
  между процессами; при отсутствии/нестарте RpcSs он падает в `0x80004002` — на in-proc звук,
  графику и управление не влияет.
- `{2fe8f810-b2a5-11d0-a787-0000f803abfc}` — класс из тома DirectShow/DirectMusic, в этом профиле
  не зарегистрирован; игра работает без него.

Отдельно проверено, что эти строки **не связаны с буфером звука**: они появляются и при чистом
звуке, и при кривом.

---

## 4. Грабли, на которые уже наступили

- **`timeout N wine …` не убивает Wine** (игнорирует SIGTERM) — только `timeout -s KILL N`.
- **`grep` по `system.reg` и по выводу `wine reg …` требует `-a`**, иначе «двоичный файл совпадает».
- **Не путать**: `Failed to open RpcSs service` (службы нет в реестре) и
  `Failed to start RpcSs service` (есть, но не поднялась).
- **Перезапуск PipeWire стирает runtime-настройку** `pw-metadata` — поэтому она и вынесена в службу.
- **`pkill -f <слово>`, встречающееся в собственной команде, убивает саму оболочку** — использовать
  `pkill -x <имя-процесса>` либо kill по PID.
- **Проверять звук не «на слух вообще», а на конкретном сигнале** и с учётом того, что часть
  «щелчков» может давать железо (у нас один раз колонка отваливалась по BT, и это выглядело
  как «звука нет» при исправном PipeWire).
