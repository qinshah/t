"""Windows 输入/截图小工具（纯 ctypes，无第三方依赖）。

用法见文件末尾的 __main__ 分支。
只用于本地 IME 实测：截图 + 真实按键（让输入法自己处理）。
"""

import ctypes
import ctypes.wintypes as wt
import struct
import sys
import time

user32 = ctypes.WinDLL("user32", use_last_error=True)
gdi32 = ctypes.WinDLL("gdi32", use_last_error=True)

SRCCOPY = 0x00CC0020
DIB_RGB_COLORS = 0
BI_RGB = 0


class BITMAPINFOHEADER(ctypes.Structure):
    _fields_ = [
        ("biSize", wt.DWORD),
        ("biWidth", wt.LONG),
        ("biHeight", wt.LONG),
        ("biPlanes", wt.WORD),
        ("biBitCount", wt.WORD),
        ("biCompression", wt.DWORD),
        ("biSizeImage", wt.DWORD),
        ("biXPelsPerMeter", wt.LONG),
        ("biYPelsPerMeter", wt.LONG),
        ("biClrUsed", wt.DWORD),
        ("biClrImportant", wt.DWORD),
    ]


class BITMAPINFO(ctypes.Structure):
    _fields_ = [("bmiHeader", BITMAPINFOHEADER), ("bmiColors", wt.DWORD * 3)]


user32.FindWindowW.restype = wt.HWND
user32.FindWindowW.argtypes = [wt.LPCWSTR, wt.LPCWSTR]
user32.GetClientRect.argtypes = [wt.HWND, ctypes.POINTER(wt.RECT)]
user32.ClientToScreen.argtypes = [wt.HWND, ctypes.POINTER(wt.POINT)]


def find_window_ex(title):
    """按标题精确查找（FindWindowW，返回 64 位句柄）。"""
    return user32.FindWindowW(None, title) or None


def window_rect(hwnd):
    rect = wt.RECT()
    user32.GetClientRect(hwnd, ctypes.byref(rect))
    origin = wt.POINT(0, 0)
    user32.ClientToScreen(hwnd, ctypes.byref(origin))
    return origin.x, origin.y, rect.right, rect.bottom


def find_window(title):
    hwnd = user32.FindWindowW(None, title)
    return hwnd or None


def focus(hwnd):
    user32.ShowWindow(hwnd, 9)  # SW_RESTORE
    user32.SetForegroundWindow(hwnd)
    time.sleep(0.35)


def shot(path, x=0, y=0, w=None, h=None):
    """把屏幕区域存成 BMP（DIB 直接落盘，无编码依赖）。"""
    if w is None:
        w = user32.GetSystemMetrics(0)
        h = user32.GetSystemMetrics(1)
    screen_dc = user32.GetDC(0)
    mem_dc = gdi32.CreateCompatibleDC(screen_dc)
    bmp = gdi32.CreateCompatibleBitmap(screen_dc, w, h)
    gdi32.SelectObject(mem_dc, bmp)
    gdi32.BitBlt(mem_dc, 0, 0, w, h, screen_dc, x, y, SRCCOPY)

    info = BITMAPINFO()
    info.bmiHeader.biSize = ctypes.sizeof(BITMAPINFOHEADER)
    info.bmiHeader.biWidth = w
    info.bmiHeader.biHeight = -h  # 负数 = 自上而下
    info.bmiHeader.biPlanes = 1
    info.bmiHeader.biBitCount = 32
    info.bmiHeader.biCompression = BI_RGB

    buf = ctypes.create_string_buffer(w * h * 4)
    gdi32.GetDIBits(mem_dc, bmp, 0, h, buf, ctypes.byref(info), DIB_RGB_COLORS)

    pixel_size = w * h * 4
    header = struct.pack("<2sIHHI", b"BM", 14 + 40 + pixel_size, 0, 0, 54)
    info_header = struct.pack(
        "<IiiHHIIiiII", 40, w, -h, 1, 32, BI_RGB, pixel_size, 0, 0, 0, 0
    )
    with open(path, "wb") as f:
        f.write(header)
        f.write(info_header)
        f.write(buf.raw)

    gdi32.DeleteObject(bmp)
    gdi32.DeleteDC(mem_dc)
    user32.ReleaseDC(0, screen_dc)
    return path


# --- 键盘 ---------------------------------------------------------------

KEYEVENTF_KEYUP = 0x0002
KEYEVENTF_EXTENDEDKEY = 0x0001

VK = {
    "shift": 0x10,
    "ctrl": 0x11,
    "alt": 0x12,
    "win": 0x5B,
    "space": 0x20,
    "enter": 0x0D,
    "back": 0x08,
    "esc": 0x1B,
    "tab": 0x09,
    "left": 0x25,
    "up": 0x26,
    "right": 0x27,
    "down": 0x28,
    "delete": 0x2E,
    "home": 0x24,
    "end": 0x23,
}


class KEYBDINPUT(ctypes.Structure):
    _fields_ = [
        ("wVk", wt.WORD),
        ("wScan", wt.WORD),
        ("dwFlags", wt.DWORD),
        ("time", wt.DWORD),
        ("dwExtraInfo", ctypes.POINTER(ctypes.c_ulong)),
    ]


class INPUT_UNION(ctypes.Union):
    _fields_ = [("ki", KEYBDINPUT), ("padding", ctypes.c_byte * 32)]


class INPUT(ctypes.Structure):
    _fields_ = [("type", wt.DWORD), ("u", INPUT_UNION)]


EXTENDED_VKS = {0x25, 0x26, 0x27, 0x28, 0x2E, 0x2D, 0x24, 0x23, 0x21, 0x22,
                0x5B, 0x5C, 0xA3, 0xA5, 0x90}


def _send(vk, up=False):
    """带扫描码地发送一次按键（Flutter 在 Windows 上按扫描码判定物理键）。"""
    scan = user32.MapVirtualKeyW(vk, 0)
    flags = 0
    if vk in EXTENDED_VKS:
        flags |= KEYEVENTF_EXTENDEDKEY
    if up:
        flags |= KEYEVENTF_KEYUP
    inp = INPUT(type=1)
    inp.u.ki = KEYBDINPUT(vk, scan, flags, 0, None)
    user32.SendInput(1, ctypes.byref(inp), ctypes.sizeof(INPUT))


def tap(vk, delay=0.02):
    _send(vk)
    time.sleep(delay)
    _send(vk, up=True)
    time.sleep(delay)


def chord(mods, vk):
    for m in mods:
        _send(VK[m])
    time.sleep(0.05)
    tap(vk)
    for m in reversed(mods):
        _send(VK[m], up=True)
    time.sleep(0.1)


def type_ascii(text, delay=0.06):
    """按物理键敲 ASCII（走输入法，因此中文输入法会开始组词）。"""
    for ch in text:
        if ch == " ":
            tap(VK["space"])
        elif ch == "\n":
            tap(VK["enter"])
        elif ch.isalpha():
            tap(ord(ch.upper()))
        elif ch.isdigit():
            tap(ord(ch))
        else:
            raise ValueError(ch)
        time.sleep(delay)


def foreground():
    user32.GetForegroundWindow.restype = wt.HWND
    return user32.GetForegroundWindow()


def click(x, y):
    user32.SetCursorPos(int(x), int(y))
    time.sleep(0.1)
    user32.mouse_event(0x0002, 0, 0, 0, 0)  # LEFTDOWN
    time.sleep(0.05)
    user32.mouse_event(0x0004, 0, 0, 0, 0)  # LEFTUP
    time.sleep(0.3)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "shot"
    if cmd == "shot":
        out = sys.argv[2] if len(sys.argv) > 2 else "screen.bmp"
        if len(sys.argv) > 6:
            shot(out, *[int(v) for v in sys.argv[3:7]])
        else:
            shot(out)
        print(out)
    elif cmd == "type":
        type_ascii(sys.argv[2])
    elif cmd == "tap":
        tap(VK[sys.argv[2].lower()])
    elif cmd == "chord":
        chord(sys.argv[2].split("+")[:-1], VK[sys.argv[2].split("+")[-1].lower()])
    elif cmd == "focus":
        hwnd = find_window(sys.argv[2])
        print(hwnd)
        if hwnd:
            focus(hwnd)
    elif cmd == "rect":
        hwnd = find_window(sys.argv[2])
        print(window_rect(hwnd) if hwnd else "not found")
