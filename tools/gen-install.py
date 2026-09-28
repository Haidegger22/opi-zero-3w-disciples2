#!/usr/bin/env python3
# gen-install.py — дописывает в INSTALL.md раздел «Полный код файлов (установка без git)».
# Запускать из корня репозитория. Текстовые шаги в INSTALL.md пишутся ДО запуска:
# генератор дописывает раздел в конец файла (маркер «## Полный код файлов»).
import io, os, sys

D = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # корень репозитория
INSTALL = os.path.join(D, "INSTALL.md")
MARKER = "## Полный код файлов (установка без git)"

# (путь в репо, куда ставить у читателя, подпись)
FILES = [
    ("scripts/disc2-zero.sh",          "$HOME/.local/bin/disc2-zero.sh",          "Лаунчер игры"),
    ("scripts/fix-mmdevenum.sh",       "$HOME/.local/bin/fix-mmdevenum.sh",       "Регистрация COM-класса MMDeviceEnumerator (звук)"),
    ("scripts/fix-rpcss-service.sh",   "$HOME/.local/bin/fix-rpcss-service.sh",   "Регистрация службы RpcSs (RPC/OLE)"),
    ("scripts/diagnose-wine-prefix.sh","$HOME/.local/bin/diagnose-wine-prefix.sh","Диагностика профиля Wine"),
    ("scripts/verify-launcher.sh",     "$HOME/.local/bin/verify-launcher.sh",     "Проверка запуска (окно + звук)"),
    ("scripts/fix-audio-buffer.sh",    "$HOME/.local/bin/fix-audio-buffer.sh",    "Постоянный буфер звука 1024 кадра (лечит хрипы)"),
    ("scripts/set-fullscreen.sh",      "$HOME/.local/bin/set-fullscreen.sh",      "Полный экран игры / возврат в окно"),
    ("scripts/d2-ini-set.sh",          "$HOME/.local/bin/d2-ini-set.sh",          "Правка одного параметра Disciple.ini (бэкап + диф)"),
    ("scripts/set-resolution.sh",      "$HOME/.local/bin/set-resolution.sh",      "Разрешение картинки игры (DisplayWidth/DisplayHeight)"),
    ("scripts/verify-game-state.sh",   "$HOME/.local/bin/verify-game-state.sh",   "Снимок состояния игры: окно, настройки, бэкапы"),
    ("reg/mmdevenum-wow6432.reg",      "$HOME/mmdevenum-wow6432.reg",             "То же, что fix-mmdevenum, но файлом .reg"),
    ("reg/rpcss-service.reg",          "$HOME/rpcss-service.reg",                 "То же, что fix-rpcss-service, но файлом .reg"),
    ("desktop/disciples2.desktop",     "$HOME/.local/share/applications/disciples2.desktop", "Ярлык"),
]


def rd(p):
    with io.open(p, encoding="utf-8") as fh:
        return fh.read()


def main():
    h = rd(INSTALL)
    if MARKER not in h:
        sys.exit("в INSTALL.md нет маркера: " + MARKER)
    h = h.split(MARKER)[0].rstrip() + "\n\n" + MARKER + "\n\n"
    h += ("Ниже — те же файлы целиком, если удобнее создавать их руками (например, без git).\n"
          "Копируйте блоки по порядку; делимитер `'SCRIPT_EOF'` в кавычках обязателен.\n\n")
    for i, (src, dst, title) in enumerate(FILES, 1):
        h += "### %d. %s\n\n" % (i, title)
        h += "```bash\nmkdir -p $(dirname %s)\ncat > %s << 'SCRIPT_EOF'\n%sSCRIPT_EOF\nchmod +x %s 2>/dev/null || true\n```\n\n" % (
            dst, dst, rd(os.path.join(D, src)), dst)
    with io.open(INSTALL, "w", encoding="utf-8") as fh:
        fh.write(h)
    print("INSTALL.md: строк=%d, блоков SCRIPT_EOF=%d (ожидалось %d)" % (
        h.count("\n"), h.count("SCRIPT_EOF"), len(FILES) * 2))


if __name__ == "__main__":
    main()
