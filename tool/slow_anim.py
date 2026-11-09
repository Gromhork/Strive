"""Slows the exercise demo animations (assets/exercises/anim/*.webp) down to ~0.55x by
rewriting the frame durations in the ANMF chunks in place (no re-encoding, same size).

Idempotent: only frames shorter than 150 ms (the 100 ms source timing) are changed.
Usage: python tool/slow_anim.py
"""
import glob, os, struct

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGET_MS = 180  # 100 ms / 0.55

changed = 0
for path in glob.glob(os.path.join(ROOT, 'assets', 'exercises', 'anim', '*.webp')):
    data = bytearray(open(path, 'rb').read())
    i, dirty = 12, False
    while i + 8 <= len(data):
        tag = bytes(data[i:i + 4])
        size = struct.unpack('<I', data[i + 4:i + 8])[0]
        if tag == b'ANMF':
            off = i + 8 + 12  # X, Y, width-1, height-1 (3 bytes each), then duration
            dur = int.from_bytes(data[off:off + 3], 'little')
            if dur < 150:
                data[off:off + 3] = (TARGET_MS if dur in (0, 100) else round(dur / 0.55)).to_bytes(3, 'little')
                dirty = True
        i += 8 + size + (size & 1)
    if dirty:
        open(path, 'wb').write(data)
        changed += 1
print('patched', changed)
