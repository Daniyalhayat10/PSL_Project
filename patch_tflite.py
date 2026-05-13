"""
Patch a TFLite model's FULLY_CONNECTED op version for compatibility with
older TFLite runtimes.  No external dependencies — pure Python stdlib.
"""
import struct, os, sys

MODELS = [
    r"D:\dannything_project\PSL_Project\PSL_Project_Fixed\PSL_Fixed\assets\models\hand_landmark_nn.tflite",
    r"D:\dannything_project\PSL_Project\PSL_Project_Fixed\PSL_Fixed\assets\models\hand_landmark_lite.tflite",
]
TARGET_VERSION      = 9   # downgrade to v9 (supported by TFLite 2.11+)
FULLY_CONNECTED     = 9   # BuiltinOperator.FULLY_CONNECTED enum value

# ---------- minimal flatbuffer helpers ----------
def ru32(b, p): return struct.unpack_from('<I', b, p)[0]
def ri32(b, p): return struct.unpack_from('<i', b, p)[0]
def ru16(b, p): return struct.unpack_from('<H', b, p)[0]
def ru8 (b, p): return struct.unpack_from('B',  b, p)[0]
def wi32(b, p, v): struct.pack_into('<i', b, p, v)

def field_pos(buf, tbl, idx):
    """Absolute position of field idx's value inside table tbl, or None."""
    vtbl = tbl - ri32(buf, tbl)
    size = ru16(buf, vtbl)
    fp   = vtbl + 4 + idx * 2
    if fp + 2 > vtbl + size: return None
    off  = ru16(buf, fp)
    return None if off == 0 else tbl + off

def vec_items(buf, tbl, idx):
    """List of table positions from a vector field."""
    fp = field_pos(buf, tbl, idx)
    if fp is None: return []
    vp = fp + ru32(buf, fp)
    return [vp + 4 + i*4 + ru32(buf, vp + 4 + i*4) for i in range(ru32(buf, vp))]
# ------------------------------------------------

for path in MODELS:
    if not os.path.exists(path):
        print(f"SKIP (not found): {path}"); continue

    with open(path, 'rb') as f:
        buf = bytearray(f.read())

    fid  = buf[4:8].decode('ascii', errors='replace')
    root = ru32(buf, 0)
    print(f"\n{'='*60}")
    print(f"File : {os.path.basename(path)}  ({len(buf):,} bytes)  id={fid}")
    print(f"Root table @ {root}")

    ops = vec_items(buf, root, 1)        # Model.operator_codes = field 1
    print(f"Operator codes: {len(ops)}")

    patched = 0
    for i, op in enumerate(ops):
        dp  = field_pos(buf, op, 0)      # deprecated_builtin_code (byte)
        vp  = field_pos(buf, op, 2)      # version (int32)
        bp  = field_pos(buf, op, 3)      # builtin_code (int32)

        builtin = ri32(buf, bp) if bp else 0
        depr    = ru8 (buf, dp) if dp else 0
        ver     = ri32(buf, vp) if vp else 1
        code    = builtin if builtin else depr

        label = "FULLY_CONNECTED" if code == FULLY_CONNECTED else f"builtin_{code}"
        print(f"  [{i}] builtin={builtin:3d} depr={depr:3d}  {label:<22}  v{ver}")

        if code == FULLY_CONNECTED and ver > TARGET_VERSION and vp:
            wi32(buf, vp, TARGET_VERSION)
            print(f"       ↳ patched v{ver} → v{TARGET_VERSION}  ✅")
            patched += 1

    if patched:
        with open(path, 'wb') as f: f.write(buf)
        print(f"Saved ({patched} patch(es)): {path}")
    else:
        print(f"No patches needed (all FC ops already ≤ v{TARGET_VERSION})")

print("\nDone.")
