"""裁切 BMP 的一小块并放大保存（BMP -> BMP，纯 struct）。"""

import struct
import sys


def read_bmp(path):
    data = open(path, "rb").read()
    offset = struct.unpack_from("<I", data, 10)[0]
    width, height = struct.unpack_from("<ii", data, 18)
    bpp = struct.unpack_from("<H", data, 28)[0]
    stride = width * 4
    return data[offset:], width, height, bpp, stride


def write_bmp(path, pixels, width, height):
    size = width * height * 4
    header = struct.pack("<2sIHHI", b"BM", 54 + size, 0, 0, 54)
    info = struct.pack("<IiiHHIIiiII", 40, width, height, 1, 32, 0, size, 0, 0, 0, 0)
    with open(path, "wb") as f:
        f.write(header + info + pixels)


def crop(src, dst, x, y, w, h, scale=2):
    pixels, width, height, bpp, stride = read_bmp(src)
    assert bpp == 32, bpp
    out = bytearray(w * scale * h * scale * 4)
    for row in range(h):
        for col in range(w):
            si = row * stride + col * 4
            px = pixels[si:si + 4]
            for dy in range(scale):
                base = ((row * scale + dy) * (w * scale) + col * scale) * 4
                for dx in range(scale):
                    out[base + dx * 4: base + dx * 4 + 4] = px
    write_bmp(dst, bytes(out), w * scale, h * scale)
    print(dst, w * scale, h * scale)


if __name__ == "__main__":
    crop(sys.argv[1], sys.argv[2], *[int(v) for v in sys.argv[3:8]])
