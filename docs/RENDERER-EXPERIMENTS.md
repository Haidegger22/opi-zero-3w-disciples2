# Попытки аппаратного рендера игры: что пробовали и почему не пошло

Проверено на Orange Pi Zero 3W 28.09.2026 (Wine 11.16 Hangover, профиль `~/.wine-hg2`,
игра `~/d2-ru-pack/app`, экран 1024×600). Оба опыта **откачены**, игра работает на
встроенном DirectDraw (софтверный рендер).

## Итоговое состояние

- игра рисуется **встроенным `ddraw` Wine** (софт, процессор) — картинка чистая, полный экран 1024×600;
- лаунчер намеренно ставит `WINEDLLOVERRIDES="ddraw=b;d3d8=b;d3d9=b;d3d10core=b;d3d11=b;dxgi=b"`;
- аппаратный OpenGL на плате **есть**, но игра им не пользуется (см. ниже), и включить его двумя
  разными способами **не удалось**.

## Опыт 1 — cnc-ddraw (подмена `ddraw.dll`) → ЧЁРНЫЙ ЭКРАН

Что делали: скачали `cnc-ddraw v7.1.0.0` (`FunkyFr3sh/cnc-ddraw`), положили `ddraw.dll` +
`ddraw.ini` + `Shaders/` в каталог игры, `renderer` задали `opengl`, прогон в два этапа
(сначала `gdi`, затем `opengl`).

Результат: **звук есть, изображения нет** (чёрный экран). По логам видно, что это случилось
уже на этапе с `renderer=gdi` — до этапа `opengl` дело не дошло, то есть дело **не в zink**
и не в аппаратном GL. `ddraw.log` от cnc-ddraw так и не появился — точную строку-причину
назвать не можем.

Наиболее вероятная причина: игра **сама оборачивает DirectDraw** — в каталоге есть
`C4dll-R.dll`, который экспортирует `DirectDrawCreate/Ex/EnumerateExA` и читает
`UseD3D`/`ForceD3DPow2` из `Disciple.ini`. Подменённый `ddraw.dll` с этой обёрткой не стыкуется.

Откат: `ddraw.dll` и `ddraw.ini` вынесены в `~/cnc-ddraw/` (`ddraw.dll.removed`,
`ddraw.ini.removed`), каталог игры чистый.

## Опыт 2 — родной D3D-рендерер игры (`UseD3D=1`) → БЕЛЫЙ ЭКРАН

Что делали: в `Disciple.ini` поставили `UseD3D=1` (у игры есть два рендерера: `CDisplayD3D`
и `CDisplayDDraw`) и запустили с аппаратным GL (Vulkan-слой feature-strip + `zink` → PowerVR).

Результат: **белый экран**. Откат — вернули `UseD3D=0`, картинка сразу вернулась
(проверено скриншотом: главное меню, полный экран).

Не пробовали (возможно, но не проверялось): `UseD3D=1` **без** слоя, то есть на `llvmpipe` —
не исключено, что белый экран даёт именно zink, а софтверный D3D7 поедет. Если пробовать —
с бэкапом `Disciple.ini` и сразу снимать скриншот.

## Что известно про аппаратный OpenGL на этой плате

Собран и установлен Vulkan-слой **feature-strip** (из `a733-powervr-fex`,
`gpu/vk-feature-strip`): он подделывает `geometryShader`, без которого Mesa отказывалась
работать с проприетарным драйвером PowerVR:

```
# без слоя
MESA: error: zink: Imagination proprietary driver w/o geometryShader is unsupported
OpenGL renderer string: llvmpipe (LLVM 19.1.7, 128 bits)

# со слоем (PVR_FAKE_GS=1 + VK_LAYER_PATH + VK_INSTANCE_LAYERS=VK_LAYER_PVR_strip
#           + GALLIUM_DRIVER=zink + MESA_LOADER_DRIVER_OVERRIDE=zink)
OpenGL renderer string: zink Vulkan 1.3(PowerVR B-Series BXM-4-64 MC1 (IMAGINATION_PROPRIETARY))
OpenGL version string: 2.1 Mesa 25.0.7
```

Слой лежит в `~/.local/share/vulkan/implicit_layer.d/` (`libVkLayer_PVR_strip.so` +
`VkLayer_PVR_strip.json`), откат — «Шаг 1» в `~/pvr-work/ZERO-GPU-PLAN.md`.
Важно: zink при этом **предупреждает**, что устройство не покрывает базовые требования —
отсутствует `feats.features.fillModeNonSolid`. Это ожидаемо для блоба PowerVR и,
по-видимому, и есть причина, почему D3D7-путь игры через zink не рисует.

Не путать: **обычный** `glxinfo -B` (без переменных слоя) всегда показывает `llvmpipe` —
это не поломка, а признак того, что слой не активирован.

## Что осталось из плана (не пробовано)

- **Шаг 2 плана Джарвиса:** DXVK-Sarek **x32** (i386) в отдельный новый профиль Wine —
  2–4 часа, отдельная задача; arm64ec-сборка для 32-битной игры не годится.
  Уже собранный x32-набор: `~/DXVK-Sarek/build/x32/` (проверен `d7vk`:
  `DirectDrawCreate → IDirectDraw7 → GetDisplayMode 1024x600`).
  Учесть: DXVK вообще не реализует `ddraw`, поэтому «чистый DirectDraw через DXVK» закрыт;
  для этой игры путь только через d7vk/D3D7.
- **Шаг 3** — поднять частоту GPU (вендорский драйвер держит фиксированные 600 МГц),
  оверлей `gpu-clk.dts`. На 2D-игру влияния почти не окажет.
- **`UseD3D=1` на llvmpipe** (см. выше).

## Чего не делать (по граблям этого стека)

- Не включать glamor/GPU-композитор и Wayland-композитор — дедлок ядра, лечится только power-cycle.
- Не обновлять mesa до 26.x: zink упрётся в `robustness2`, которого у блоба нет.
- Не ставить `DXVK_HUD` — тот же класс дедлока.
- Не менять файлы игры при запущенном Wine (кешируются данные, получаем абракадабру/краш).
