"""按脚本驱动的真机场景测试：type/tap/shot/sleep 用逗号串联。

示例: python scenario.py "type:nihao,shot:a,tap:space,shot:b"
每步之间默认等 0.35s；shot 立即截图到 step_<name>.bmp。
"""

import os
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import winio  # noqa: E402

TMP = os.path.dirname(os.path.abspath(__file__))
EXE = r"C:\Users\qshh\Desktop\Code\FA\t\build\windows\x64\runner\Debug\t.exe"


def main():
    steps = sys.argv[1]
    log = open(os.path.join(TMP, "app.log"), "w", encoding="utf-8", errors="replace")
    proc = subprocess.Popen([EXE], stdout=log, stderr=subprocess.STDOUT)
    time.sleep(6)
    hwnd = winio.find_window_ex("t")
    if not hwnd:
        print("no window")
        proc.terminate()
        return
    winio.focus(hwnd)
    x, y, w, h = winio.window_rect(hwnd)
    winio.click(x + w // 2, y + h // 3)
    print("fg", winio.foreground() == hwnd, flush=True)
    time.sleep(0.6)

    for step in steps.split(","):
        name, _, arg = step.partition(":")
        if name == "type":
            winio.type_ascii(arg)
        elif name == "tap":
            winio.tap(winio.VK[arg])
        elif name == "shot":
            winio.shot(os.path.join(TMP, f"step_{arg}.bmp"), x, y, w, h)
            print("shot", arg, flush=True)
        elif name == "sleep":
            time.sleep(float(arg))
        time.sleep(0.35)

    proc.terminate()
    time.sleep(0.5)


if __name__ == "__main__":
    main()
