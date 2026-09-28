# Disciples II: Gold (русская версия) на Orange Pi Zero 3W

Запуск **Disciples II: Gold v3.01** (русская сборка Rise of the Elves / Gallean's Return) на
**Orange Pi Zero 3W** (Allwinner A733) через **Wine 11.16 Hangover** — то есть arm64-Wine
с PE-библиотеками, **без box64**.

Плата: Debian 13 «Trixie» (Orange Pi 1.0.2), ядро 6.6.98-sun60iw2, X11/MATE, дисплей 1024×600.
Игра лежит распакованной (GOG-инсталляторы распаковываются `innoextract`, а не запускаются в Wine).

## Статус (проверено на плате 28.09.2026)

- игра стартует и **открывает окно «Disciples II» за ~15 секунд** (800×534);
- **звук идёт реальным потоком** в PipeWire: в `pactl list sink-inputs` виден
  `application.name = "Disciples II v3.01"`;
- лог запуска **чистый: 0 строк с `err:`**;
- рабочий профиль: `~/.wine-hg2`, каталог игры: `~/d2-ru-pack/app`.

Чтобы это заработало, пришлось обойти две независимые проблемы — обе разобраны и
закрыты скриптами в этом репозитории:

1. **Нет звука: COM-класс `MMDeviceEnumerator` не зарегистрирован.**
   `err:dsound:get_mmdevenum CoCreateInstance failed: 80040154`
   (`REGDB_E_CLASSNOTREG`) → `DirectSoundDevice_Initialize invalid parameter: lpcGUID`.
   Лечение: `scripts/fix-mmdevenum.sh`.
2. **Нет службы `RpcSs` в реестре профиля — ошибки OLE/RPC.**
   `err:ole:start_rpcss Failed to open RpcSs service`,
   `err:ole:apartment_get_local_server_stream Failed: 0x80004002`.
   Лечение: `scripts/fix-rpcss-service.sh`.

Подробный разбор обеих (с исходниками Wine, номерами багов и воспроизводимыми
проверками) — **[docs/RPCSS-AND-COM-NOTES.md](docs/RPCSS-AND-COM-NOTES.md)**.

## Быстрый путь

Пошаговая инструкция с полным кодом всех файлов (можно ставить без `git clone`) —
**[INSTALL.md](INSTALL.md)**.

Кратко:

```bash
# 1) зависимости (Wine для arm64 — дистрибутивный Hangover)
sudo apt install -y hangover-wine                                        # Debian 13 Trixie
# 2) скрипты в ~/.local/bin
install -m755 scripts/disc2-zero.sh scripts/fix-mmdevenum.sh \
              scripts/fix-rpcss-service.sh scripts/diagnose-wine-prefix.sh ~/.local/bin/
# 3) вылечить профиль Wine
fix-mmdevenum.sh ~/.wine-hg2
fix-rpcss-service.sh ~/.wine-hg2
# 4) проверить и запустить
diagnose-wine-prefix.sh ~/.wine-hg2
disc2-zero.sh
```

## Что в репозитории

- `scripts/disc2-zero.sh` — лаунчер: гасит висячие сессии Wine, включает builtin-оверрайды
  `ddraw;d3d8;d3d9;d3d10core;d3d11;dxgi`, подставляет системный `LD_LIBRARY_PATH`
  (вендорские `libEGL/libGLESv2` от PowerVR ломают создание GL-контекста у Wine —
  `err:wgl:internal_context_create`), запускает игру из её каталога.
- `scripts/fix-mmdevenum.sh` — регистрирует `MMDeviceEnumerator` (`{bcde0395-…692e}`)
  в `HKLM\Software\Classes\Wow6432Node\CLSID\…` (32-битное представление реестра).
- `scripts/fix-rpcss-service.sh` — прописывает службу `RpcSs` в
  `HKLM\System\CurrentControlSet\Services\RpcSs` и проверяет её запуск через `sc`.
- `scripts/diagnose-wine-prefix.sh` — диагностика профиля: сколько служб Wine потеряно,
  есть ли класс звука, отвечает ли SCM; в конце печатает вердикт и что делать.
- `scripts/verify-launcher.sh` — проверка «как у пользователя»: запускает лаунчер,
  ждёт окно `xdotool`-ом, смотрит звуковой поток и ошибки в логе.
- `reg/` — те же правки в виде `.reg`-файлов (`wine reg import`).
- `docs/` — разбор причин: RpcSs, `WINE_REGISTRY`, баги WineHQ.

## Ограничения и что НЕ проверено

- Скрипты **дописывают реестр существующего профиля**. Они не лечат причину, по которой
  профиль оказался «полупостроенным»: на этой плате `wineboot -u` для свежего профиля
  **зависает** (`C:\windows\system32\wineboot.exe` остаётся жить, лог обрывается на
  `err:wgl:internal_context_create Failed to create internal thread context`), и профиль
  остаётся без служб и без части реестровых веток. Проверено: в свежем профиле
  `system.reg` содержит 18 ключей, 0 служб и 0 классов CLSID.
- Проверено на **этой** плате и **этой** сборке игры. На другом железе/дистрибутиве
  набор библиотек и `LD_LIBRARY_PATH` могут отличаться.
- Звук на Zero 3W выводится через HDMI (ALSA-карта `allwinner-hdmi`) — аналогового выхода нет.
- Прочие службы Wine (`MountMgr`, `PlugPlay`, `Eventlog`, `NDIS`, `nsiproxy`, …) в таком
  профиле тоже отсутствуют — `diagnose-wine-prefix.sh` показывает полный список.
  Отдельный скрипт для них не нужен: если восстанавливать, то все разом из `wine.inf`.

## Ссылки

- WineHQ Bugzilla 50168 — `Error when running notepad.exe: Failed to start RpcSs service`
  (CLOSED/FIXED): регрессия в `advapi32` (`SystemFunction036` → `getrandom()`), симптом —
  «большинство служб отсутствует в свежесозданном `system.reg`, `RpcSs` в их числе».
- WineHQ Bugzilla 51428 — `err:ole:start_rpcss Failed to open RpcSs service` (DUPLICATE).
- WineHQ Bugzilla 58554 — та же строка в 2025 году (CLOSED/INVALID: конфигурация отчёта).
- Исходники: `dlls/combase/rpc.c` (`start_rpcss`), `dlls/setupapi/install.c`
  (`SetupInstallServicesFromInfSectionW`), `programs/wineboot/wineboot.c`.
