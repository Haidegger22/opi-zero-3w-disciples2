# Настройки игры и русской обёртки (`Disciple.ini`)

Документ про то, **чем управляются картинка, скорость и поведение игры** в сборке
Disciples II: Gold v3.01 на Orange Pi Zero 3W. Здесь же — разбор случая «после смены
разрешения бой стал быстрее» и справочник параметров обёртки.

Сборка игры идёт с **русской обёрткой** `C4dll-R.dll` (2022 год) — это отдельная
надстройка над оригинальным `Disciples2.exe`, которая умеет:

- нестандартные разрешения и 32-битный рендер (`HD=1`);
- выбирать рендерер (OpenGL 1.1/2.0/3.0 / GDI);
- фильтры увеличения и интерполяции картинки (xBRZ, ScaleHQ, Eagle, Lanczos…);
- **собственное управление скоростью анимации** (`SpeedEnabled` + `GameSpeed`);
- границы и фон игровых окон, зум окон, прокрутку карты, зеркальные фоны боя и т. д.

Настройки всех трёх уровней лежат в одном файле — **`Disciple.ini`** в каталоге игры
(`~/d2-ru-pack/app`), в кодировке **cp1251**. Секции:

| Секция | Кто хозяин | Что задаёт |
|---|---|---|
| `[Disciple]` | игра | полный экран/окно (`DisplayMode`), звук, `UseD3D` (0 = встроенный DirectDraw, 1 = родной D3D7) |
| `[Settings]` | игра | скорость анимации и боя, прокрутка, автосохранение, громкости |
| `[Wrapper]` | обёртка | разрешение, рендерер, фильтры, скорость анимации обёртки, окна, мышь |
| `[FunktionKeys]` | обёртка | назначение горячих клавиш |

## Главное правило: файл может перезаписать игра

`Disciple.ini` пишет не только человек. Наблюдение с этой платы (29.09.2026):

- в 00:13 бэкап содержал `BattleSpeed=2`, `DisplayWidth=800`;
- в 00:21 те же значения читались в файле;
- в 00:26 файл уже содержал `BattleSpeed=1` — это сделала **игра**: настройки, изменённые
  в её собственном меню, она сохраняет в `Disciple.ini` при выходе;
- после моей правки той же строки файл оказался **байт в байт** равен бэкапу, сделанному
  секундой раньше, — то есть правка была пустой, и это сразу видно, если сверять с бэкапом.

Практические следствия:

1. **Правьте `Disciple.ini` только при закрытой игре.** Иначе есть шанс, что игра
   перезапишет файл своими значениями и правка «не применится».
2. **Всегда делайте бэкап** — так видно, что именно изменилось, и есть откат в одну команду.
3. **После правки сверяйте диф с бэкапом.** Пустой диф = вы поменяли то, что уже стояло.
4. Если настроили через меню игры — файл уже содержит нужное, повторять вручную не надо.

## Разрешение: 800×600 → 1024×600

По умолчанию сборка шла с `DisplayWidth=800`, `DisplayHeight=600`, а экран платы — 1024×600,
то есть кадр 800×600 растягивался до размера экрана. Выставлено (29.09.2026):

```ini
[Wrapper]
DisplayWidth=1024
DisplayHeight=600
```

Как проверено, что всё в порядке:

```bash
DISPLAY=:0 xdotool search --name 'Disciples' \
  | xargs -I{} xdotool getwindowgeometry --shell {} | grep -E 'WIDTH|HEIGHT'
# WIDTH=1024 HEIGHT=600
DISPLAY=:0 xrandr | grep -E ' connected|\*'     # HDMI-1: 1024x600 59.99*
```

Что изменилось по факту: окно стало ровно по режиму экрана (растяжения нет), детализация
кадра выросла — PNG-скриншот того же экрана стал **889 КБ против 416 КБ** до правки.
Интерфейс у Disciples II спрайтовый, фиксированного размера, поэтому при большем
разрешении элементы выглядят мельче — это нормальное поведение `HD=1`, а не артефакт.

Важные параметры обёртки рядом с разрешением: `HD=1` (включает 32-битный рендер и
нестандартные разрешения — без него большие значения не заработают), `ImageAspect=1`
(сохранять пропорции), `FullScreenMode=0` (эксклюзивный полный экран; `1` — безрамочное окно).

## Скорость: две независимые системы

Это ключевой момент, из-за которого «настройка скорости боя не помогала».

**1) Игровые настройки** (секция `[Settings]`, подписаны в самом файле):

```ini
PlayerSpeed=2      ; Animation speed (1 - normal; 2 - fast; 3 - very fast)
OpponentSpeed=2    ; то же для противника
ScrollSpeed=50     ; Scroll speed (0 - fast; 50 - normal; 100 - slow)
BattleSpeed=1      ; Battle Speed (1 - slow; 2 - normal; 3 - fast; 4 - instant)
BattleAnim=1       ; Extra battle animation (0 - off; 1 - on)
```

**2) Ускоритель обёртки** (секция `[Wrapper]`):

```ini
GameSpeed=3        ; Animation speed (1 - ..., 5 - 1.5x 'default')   ← «5» = 1,5× от обычной
SpeedEnabled=0     ; Enables animation speed (0 - no; 1 - yes 'default')
```

Разбор реального случая: после смены разрешения бой показался быстрее, `BattleSpeed` был
поставлен в `1` — **не помогло**, потому что за темп отвечала не игровая настройка, а
ускоритель обёртки: стояло `SpeedEnabled=1` + `GameSpeed=5`, то есть **анимация шла в 1,5 раза
быстрее обычной**. Выключение ускорителя (`SpeedEnabled=0`) вернуло темп, после чего игровые
`PlayerSpeed`/`OpponentSpeed` снова стали работать как ожидается.

Дополнительный фактор (не измерен, оценивается как второстепенный): анимация в игре
привязана к кадрам, поэтому при растяжении кадра 800×600 на 1024×600 кадров в секунду было
меньше и темп казался медленнее. После перехода на нативное разрешение кадров стало больше.
Точной оценки «до/после» по кадрам у нас нет — вывод про ускоритель обёртки подтверждён
экспериментом, а это объяснение остаётся гипотезой.

Ещё у обёртки есть **переключатель скорости на горячую клавишу** — `SpeedToggle` в секции
`[FunktionKeys]` (в этой сборке `SpeedToggle=5`). Если скорость «сама» меняется в игре —
проверяйте эту привязку.

## Рабочий профиль (как настроено на плате 29.09.2026)

Подобрано пользователем в меню игры под удобный темп:

```ini
[Disciple]
DisplayMode=0      ; полный экран
UseD3D=0           ; встроенный DirectDraw (софтверный рендер)

[Settings]
PlayerSpeed=2      ; анимация «быстрая»
OpponentSpeed=2
ScrollSpeed=50     ; прокрутка «нормальная»
BattleSpeed=1      ; бой «медленный»
BattleAnim=1

[Wrapper]
HD=1
DisplayWidth=1024
DisplayHeight=600
ImageAspect=1
ImageVSync=1
Interpolation=2    ; hermite
Upscaling=0        ; без фильтров увеличения
Borders=1
Background=1
EnableZoom=1
ZoomFactor=100
FullScreenMode=0   ; эксклюзивный полный экран
GameSpeed=3
SpeedEnabled=0     ; ускоритель обёртки выключен
MirrorBattle=1
ScreenshotType=1   ; png
ScreenshotLevel=9
MessageTimeout=15
UpdateMode=1       ; сравнение изображений через SSE2
MouseScroll=3      ; прокрутка карты обеими кнопками мыши
EdgeScroll=1
EasyScroll=150
CloudsFactor=1
```

Полная копия этого файла — `config/Disciple.ini.tuned-1024x600` (снимок, в репозитории
лежит как справка: свой профиль подставляйте по своему пути и своей версии сборки).

## Справочник параметров обёртки

Описания взяты **из самой обёртки** — строки ресурсов `C4dll-R.dll` (`strings -a -n 6`),
поэтому формулировки и опечатки оригинала сохранены.

```bash
strings -a -n 6 ~/d2-ru-pack/app/C4dll-R.dll | grep -aE '\(0 -|\(1 -|\(150|\(15 '
```

| Параметр | Описание (из DLL) |
|---|---|
| `ReInit` | Reset all wrapper configurations (0 - no; 1 - yes) |
| `Renderer` | Image renderer (0 - auto 'default'; 1 - opengl 1.1; 2 - opengl 2.0; 3 - opengl 3.0; 4 - windows gdi) |
| `HD` | Enables HD options, like 32 bpp rendering and different resolutions support (0 - no; 1 - yes 'default') |
| `DisplayWidth`/`DisplayHeight` | Image resolution height (480 - min; 1024 - max) |
| `ImageAspect` | Keep image aspect ratio (0 - no; 1 - yes 'default') |
| `ImageVSync` | Enables vertical synchronization (0 - no; 1 - yes 'default') |
| `Interpolation` | Image interpolation filter (0 - none; 1 - linear; 2 - hermite; 3 - cubic; 4 - lanczos) |
| `Upscaling` | Image upscaling filter (low word: 0 - none 'default'; 1 - xbrz; 2 - scalehq; 3 - xsal; 4 - eagle; 5 - scalenx; high word - value) |
| `Borders` | Enables borders for in-game windows (0 - no; 1 - classic style 'default', 2 - alternative style) |
| `Background` | Enables background for in-game windows (0 - no 'default'; 1 - yes) |
| `EnableZoom` / `ZoomFactor` | Enables in-game windows zoom (0 - no; 1 - yes 'default') / Zoom factor (0 - 100 'default') |
| `FullScreenMode` | Full screen window mode (0 - exclusive 'default'; 1 - borderless) |
| `GameSpeed` | Animation speed (1 - ..., 5 - 1.5x 'deafult' |
| `SpeedEnabled` | Enables animation speed (0 - no; 1 - yes 'default') |
| `AlwaysActive` | Game window is always active (0 - no 'default'; 1 - yes) |
| `ColdCPU` | Decrease CPU usage for OpenGL renderer (0 - no 'default'; 1 - yes) |
| `WideBattle` | Makes window battle wider. Depends on image aspect ratio (0 - no; 1 - yes) |
| `MirrorBattle` | Allows mirrored bacgrounds for battles (0 - no; 1 - yes 'default') |
| `ScreenshotType` | Screenshots type (0 - bmp; 1 - png 'default') |
| `ScreenshotLevel` | Compression level for PNG screenshots (0 - 9, 5 - 'default') |
| `Locale` | код локали (в этой сборке `1049` — русская) |
| `MessageTimeout` | In-game messages timeout in seconds (15 'default') |
| `NoSSE2` | Disables using of SSE2 instruction set, even if it's available (0 - no 'default'; 1 - yes) |
| `UpdateMode` | Image comparison. Affects on rendering performance (0 - none; 1 - SSE2 'default'; 2 - classic; 3 - alternative) |
| `FastAI` | Increases AI performance, but may cause an unexpected game crash (0 - no 'default'; 1 - yes) |
| `MouseScroll` | Allows map scrolling by pressing mouse button (0 - no; 1 - left button; 2 - middle button; 3 - both buttons 'default') |
| `EdgeScroll` | Allows map scrolling on window/screen edge detection (0 - no; 1 - yes 'default') |
| `EasyScroll` | Easy function timeout for map scrolling (150 - 'default') |
| `CloudsFactor` | Defines clouds count multiplier (1 - min 'default') |
| `ShowBanners` | Show in-game banners for troops (0 - no 'default'; 1 - yes) |
| `ShowResources` | Show resources panel (0 - no 'default'; 1 - yes) |
| `SceneSort` | Sort scenarios (0 - by title 'default'; 1 - by file name; 2 - by map size 'ascending'; 3 - by map size 'descending') |

## Горячие клавиши (`[FunktionKeys]`)

```ini
ImageFilter=3      ; переключение фильтра изображения
WindowedMode=4     ; окно/полный экран
AspectRatio=       ; пропорции (не назначено)
VSync=             ; вертикальная синхронизация (не назначено)
ZoomImage=         ; зум (не назначено)
SpeedToggle=5      ; переключатель скорости анимации обёртки
Screenshot=12      ; скриншот
```

Пустое значение = клавиша не назначена; параметры обёртки, меняемые «на горячую», она
сохраняет в этот же файл.

## Инструменты в этом репозитории

```bash
# посмотреть текущее состояние (запущена ли игра, какое окно, что стоит в настройках)
scripts/verify-game-state.sh

# поменять ОДИН параметр в Disciple.ini: бэкап + правка cp1251 + диф + подсказка отката
scripts/d2-ini-set.sh BattleSpeed 2
scripts/d2-ini-set.sh SpeedEnabled 0

# сменить разрешение игры (закрывает игру, если она запущена)
scripts/set-resolution.sh 1024 600
```

Откат — обычной копией бэкапа:

```bash
cp ~/d2-ru-pack/app/Disciple.ini.backup-<дата-время> ~/d2-ru-pack/app/Disciple.ini
```

## Что осталось за рамками

Аппаратный рендер в игре не заведён ни одним из маршрутов (cnc-ddraw, родной `UseD3D=1`,
D7VK+DXVK) — игра работает софтверно, встроенным DirectDraw. Опыты, цифры и причины —
в `docs/RENDERER-EXPERIMENTS.md`.
