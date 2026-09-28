# Разбор причин: почему не стартует RpcSs и почему нет звука

Материал собран на Orange Pi Zero 3W (Debian 13, wine-11.16 Hangover) 28.09.2026.
Все утверждения ниже либо подтверждены запуском на плате, либо взяты из исходников
Wine / багзиллы (ссылки даны).

---

## 1. `err:ole:start_rpcss Failed to open RpcSs service`

### Откуда берётся сообщение

`dlls/combase/rpc.c`, функция `start_rpcss()` — вызывается, когда RPC-вызов к службе
IRpcss вернул `RPC_S_SERVER_UNAVAILABLE` (макросы `RPCSS_CALL_START` / `RPCSS_CALL_END`):

```c
static BOOL start_rpcss(void)
{
    SC_HANDLE scm, service;
    SERVICE_STATUS_PROCESS status;
    BOOL ret = FALSE;

    if (!(scm = OpenSCManagerW(NULL, NULL, 0))) { ERR("Failed to open service manager\n"); return FALSE; }
    if (!(service = OpenServiceW(scm, L"RpcSs", SERVICE_START | SERVICE_QUERY_STATUS)))
    {
        ERR("Failed to open RpcSs service\n");      /* <-- наша строка */
        CloseServiceHandle( scm );
        return FALSE;
    }
    if (StartServiceW(service, 0, NULL) || GetLastError() == ERROR_SERVICE_ALREADY_RUNNING)
    {
        /* ...ждём SERVICE_RUNNING до 30 секунд... */
        if (status.dwCurrentState != SERVICE_RUNNING)
            WARN("RpcSs failed to start %lu\n", status.dwCurrentState);
    }
    else
        ERR("Failed to start RpcSs service\n");
    ...
}
```

Две строки в логе означают **разные** вещи, это важно при диагностике:

- **`Failed to open RpcSs service`** — `OpenServiceW` не нашёл службу: её **нет в реестре**
  профиля (`GetLastError() == 1060`, `ERROR_SERVICE_DOES_NOT_EXIST`).
- **`Failed to start RpcSs service`** — служба в реестре есть, но `StartServiceW` упал
  (или она не дошла до `SERVICE_RUNNING`). Диагностировать: `wine sc query RpcSs`,
  `wine sc start RpcSs`, строка `err:service:process_send_start_message`.

### Почему службы нет в реестре

Список служб Wine берёт из секций `AddService` в `wine.inf`, которые обрабатывает
`wineboot` (через `setupapi`: `SetupInstallServicesFromInfSectionW` из
`dlls/setupapi/install.c`, ключи пишутся в `HKLM\System\CurrentControlSet\Services`).

В `/usr/share/wine/wine.inf` служба описана так:

```ini
[DefaultInstall.ntarm64.Services]        ; аналогичные секции для nt/ntx86/ntamd64
AddService=RpcSs,0,RpcSsService
...
[RpcSsService]
Description="RPC service"
DisplayName="Remote Procedure Call (RPC)"
ServiceBinary="%11%\rpcss.exe"           ; %11% = windows\system32
ServiceType=32
StartType=3
ErrorControl=1
```

**Замер на плате.** Профиль `~/.wine-hg2`:

```
system.reg: 445076 байт, 64 ключа
[System\ControlSet001\Services\...] -> только Tcpip\Parameters
RpcSs: нет      CLSID: нет
```

Проверка по списку из `wine.inf` — **отсутствуют все 19 служб**:
`BITS, EventLog, FontCache, FontCache3.0.0.0, HTTP, LanmanServer, MountMgr, MSIServer,
NDIS, nsiproxy, PlugPlay, RpcSs, scardsvr, Schedule, Spooler, StiSvc, TermService,
Winmgmt, wuauserv`.

То есть дело не в `RpcSs` как таковом: в этом профиле **не выполнена та часть установки
`wine.inf`, которая создаёт службы**. Дополнительное подтверждение — свежий профиль:

```
$ WINEPREFIX=~/.wine-probe-rpcss timeout 300 wineboot -u
... создан каталог, затем:
004c:err:wgl:internal_context_create Failed to create internal thread context
0054:err:wgl:internal_context_create Failed to create internal thread context
   (wineboot.exe живо — зависает; rc=124)
система.reg после этого: 18 ключей, RpcSs=0, CLSID=0
```

`wineboot` зависает и до конца установки не доходит — поэтому реестр остаётся
«полупостроенным». Это **не** ошибка конкретной игры и не ошибка профиля: так ведёт
себя свежий профиль на этой плате (вероятная причина — создание внутреннего GL-контекста
в `winex11.drv`, `wgl:internal_context_create`).

### Что об этом известно в WineHQ

- **Bug 50168** `Error when running notepad.exe: Failed to start RpcSs service` —
  CLOSED / **FIXED** (wine 6.5). Регрессия от коммита
  `e9090e1c903578b30118ce9559c1824361abc6da` («advapi32: Reimplement SystemFunction036
  using system interrupt information», переход на `getrandom()`). Цитата из комментария
  Дмитрия Тимошенко: *«…проблема проявляется в том, что большинство (но не все) служб
  отсутствуют в свежесозданном `~/.wine/system.reg`, и `RpcSs` — одна из отсутствующих»*.
  Это буквально наш симптом, только вызванный другой причиной (у нас — не завершившийся
  `wineboot`).
- **Bug 51428** `0040:err:ole:start_rpcss Failed to open RpcSs service` — CLOSED / DUPLICATE.
- **Bug 50362** (Fl Studio 20.8) — та же строка, CLOSED / FIXED (6.5).
- **Bug 58554** `err:ole:start_rpcss Failed to start RpcSs service` (2025) — CLOSED / INVALID
  (автор сам признал: причина была в конфигурации его приложения, не в Wine).
- Red Hat Bugzilla **1956242** `Winecfg fails with "Failed to open RpcSs service"`.

### Лечение (проверено)

Служба добавляется в реестр вручную; после этого SCM её видит и стартует:

```bash
# 1) файл .reg (значения — из wine.inf: Type/Start/ImagePath/ErrorControl)
cat > /tmp/rpcss-service.reg <<'EOF'
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\RpcSs]
"Type"=dword:00000010
"Start"=dword:00000003
"ImagePath"="C:\\windows\\system32\\rpcss.exe"
"ObjectName"="LocalSystem"
"DisplayName"="Remote Procedure Call (RPC)"
"Description"="RPC service"
"ErrorControl"=dword:00000001
EOF

export WINEPREFIX=~/.wine-hg2
wine reg import /tmp/rpcss-service.reg
wineserver -k        # важно: SCM читает базу служб один раз при старте
sleep 2
wine sc query RpcSs  # STATE: 1 STOPPED, TYPE: 10 WIN32_OWN_PROCESS
wine sc start RpcSs  # STATE: 4 RUNNING, WIN32_EXIT_CODE: 0
```

Результат замеров на плате (тестовый профиль-копия):

```
# до:   sc query RpcSs -> пусто / 1060
# после wine reg import:
[System\ControlSet001\Services\RpcSs]      <- CurrentControlSet это символическая ссылка
"Description"="RPC service"                    на ControlSet001, пишется туда
"DisplayName"="Remote Procedure Call (RPC)"
"ErrorControl"=dword:00000001
"ImagePath"="C:\windows\system32\rpcss.exe"
"ObjectName"="LocalSystem"
"Start"=dword:00000003
"Type"=dword:00000010

sc query RpcSs  -> TYPE: 10 WIN32_OWN_PROCESS, STATE: 1 STOPPED
sc start RpcSs  -> STATE: 4 RUNNING, WIN32_EXIT_CODE: 0 (0x0)
```

Готовый скрипт: `scripts/fix-rpcss-service.sh`. Откат: `wine reg delete
"HKLM\System\CurrentControlSet\Services\RpcSs" /f`.

Если сообщение в логе — `Failed to start` (а не `Failed to open`), регистрация уже есть,
и копать надо в запуск: `wine sc query RpcSs` (состояние и exit-код),
`ls -la $WINEPREFIX/drive_c/windows/system32/rpcss.exe` (двоичный файл, у нас
arm64-PE, 851968 байт), логи `err:service:process_send_start_message`.

---

## 2. Нет звука: `MMDeviceEnumerator` и ресурс `WINE_REGISTRY`

### Как Wine регистрирует встроенные COM-классы (это ключ к пониманию)

Классы **не** прописаны в `wine.inf` — в нём всего 18 реестровых записей, и `bcde0395`
среди них нет. Регистрация лежит **ресурсом `WINE_REGISTRY` внутри самой библиотеки**,
сгенерированным из скрипта регистрации при сборке. У `mmdevapi.dll` это видно так:

```
$ strings /usr/lib/wine/aarch64-windows/mmdevapi.dll | grep -A4 BCDE0395
HKCR
    NoRemove CLSID
    {
        '{BCDE0395-E52F-467C-8E3D-C4579291692E}' = s 'MMDeviceEnumerator class'
        {
            InprocServer32 = s '%MODULE%' { val ThreadingModel = s 'Both' }
        }
    }

$ objdump -x /usr/lib/wine/aarch64-windows/mmdevapi.dll | grep -i resource
   ... WINE_REGISTRY, значение: 0x80000018
# экспорт, который и выполняет скрипт, и импорты реестровых функций:
   __wine_register_resources / __wine_unregister_resources / register_resource
   __imp_RegCreateKeyExW, __imp_RegSetValueExW, __imp_RegOpenKeyExW, ...
```

Значит, класс прописывается в реестр **в момент загрузки библиотеки**. 32-битная игра
вызывает `CoCreateInstance(CLSID_MMDeviceEnumerator)` из `dsound` **до** того, как
`syswow64\mmdevapi.dll` окажется загружен, — и получает `REGDB_E_CLASSNOTREG`
(`0x80040154`): реестр ещё пуст, а загрузка библиотеки происходит как раз через реестр
(циклическая зависимость). Поэтому «само» это не лечится: игру надо запускать на профиле,
где класс уже прописан.

Замер на плате — **класс появляется в `Wow6432Node` (32-битное представление),
и как 32-битный InprocServer32**:

```
[Software\Classes\Wow6432Node\CLSID\{bcde0395-e52f-467c-8e3d-c4579291692e}]
@="MMDeviceEnumerator Object"

[Software\Classes\Wow6432Node\CLSID\{bcde0395-e52f-467c-8e3d-c4579291692e}\InprocServer32]
@="C:\windows\syswow64\mmdevapi.dll"
"ThreadingModel"="Both"
```

### Доказательство, что причина именно в этом (A/B-тест)

Один и тот же профиль, одна и та же игра, 25–30 секунд запуска, `WINEDEBUG=+dsound`:

| Состояние реестра | Лог игры |
|---|---|
| ключа **нет** | `err:dsound:get_mmdevenum CoCreateInstance failed: 80040154`<br>`warn:dsound:DirectSoundDevice_Initialize invalid parameter: lpcGUID` |
| ключ **есть** | ошибок нет; `trace:dsound:DirectSoundDevice_Initialize`, `trace:dsound:GetDeviceID (DSDEVID_DefaultPlayback,…)` |

После восстановления ключа полный запуск лаунчера дал окно «Disciples II» за 15 секунд и
**живой звуковой поток** в PipeWire:

```
pactl list sink-inputs
    application.name = "Disciples II v3.01"
    module-stream-restore.id = "sink-input-by-application-name:Disciples II v3.01"
```

### Лечение (проверено)

Скрипт `scripts/fix-mmdevenum.sh` (или `reg/mmdevenum-wow6432.reg` + `wine reg import`):

```bash
export WINEPREFIX=~/.wine-hg2
wine reg import mmdevenum-wow6432.reg
wineserver -w                    # дать серверу сбросить реестр на диск
wine reg query 'HKLM\Software\Classes\Wow6432Node\CLSID\{bcde0395-e52f-467c-8e3d-c4579291692e}'
```

Путь в `InprocServer32` должен указывать на **`C:\windows\syswow64\mmdevapi.dll`** для
32-битного представления (`Wow6432Node`). Для 64-битных приложений аналогичная пара
пишется в `HKLM\Software\Classes\CLSID\…` и указывает на
`C:\windows\system32\mmdevapi.dll`.

Откат: `wine reg delete 'HKLM\Software\Classes\Wow6432Node\CLSID\{bcde0395-…692e}' /f`.

---

## 3. Полезные команды диагностики

```bash
export WINEPREFIX=~/.wine-hg2 DISPLAY=:0
wine --version                                  # wine-11.16 (Hangover)
wine sc query RpcSs                             # 1060 = службы нет в реестре
wine sc start RpcSs                             # STATE: 4 RUNNING = поднялась
wine reg query 'HKLM\System\CurrentControlSet\Services'            # какие службы есть
grep -c RpcSs "$WINEPREFIX/system.reg"                             # быстрая проверка файла
grep -c bcde0395 "$WINEPREFIX/system.reg"                          # класс звука
WINEDEBUG=+dsound wine Discipl2.exe             # искать 'get_mmdevenum CoCreateInstance failed'
timeout 300 wineboot -u                         # проверить, завершается ли он вообще (у нас — нет)
```

Правило номер один при правках реестра профиля: **делайте копию `system.reg` до правки** и
после `reg import` запускайте `wineserver -w` (или `-k`), иначе чтение реестра вернёт
старое состояние — сервер держит реестр в памяти.
