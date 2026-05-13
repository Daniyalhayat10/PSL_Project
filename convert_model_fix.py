"""
Re-converts hand_landmark_nn.h5 to TFLite, working around the old Keras
'batch_shape' -> 'batch_input_shape' rename in model config.
No quantization — produces a clean float32 TFLite with the lowest op versions.
"""
import json
import h5py
import tensorflow as tf

H5  = r"D:\dannything_project\PSL_Project\PSL_Project_Fixed\PSL_Fixed\assets\models\hand_landmark_nn.h5"
OUT = r"D:\dannything_project\PSL_Project\PSL_Project_Fixed\PSL_Fixed\assets\models\hand_landmark_nn.tflite"

print(f"TF version: {tf.__version__}")

# ── Step 1: fix the model config stored in the HDF5 file ─────────────────────
with h5py.File(H5, 'r') as f:
    raw = f.attrs.get('model_config')
    if raw is None:
        raise ValueError("No model_config attribute found in the .h5 file")
    config = json.loads(raw if isinstance(raw, str) else raw.tobytes().decode('utf-8'))

def fix_config(node):
    """Recursively rename 'batch_shape' → 'batch_input_shape' in every layer config."""
    if isinstance(node, dict):
        if 'batch_shape' in node:
            node['batch_input_shape'] = node.pop('batch_shape')
        for v in node.values():
            fix_config(v)
    elif isinstance(node, list):
        for item in node:
            fix_config(item)

fix_config(config)

# ── Step 2: reconstruct model from patched config and load weights ────────────
model = tf.keras.models.model_from_config(config)
model.load_weights(H5)

print(f"Input:  {model.input_shape}")
print(f"Output: {model.output_shape}")
print(f"Layers: {len(model.layers)}")
model.summary()

# ── Step 3: convert to TFLite (no quantization — keeps FC at v9) ─────────────
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS]
converter.optimizations = []   # float32, lowest op versions

tflite_bytes = converter.convert()

with open(OUT, 'wb') as f:
    f.write(tflite_bytes)

print(f"\nSaved {len(tflite_bytes):,} bytes  →  {OUT}")

# ── Step 4: quick sanity check ────────────────────────────────────────────────
interp = tf.lite.Interpreter(model_content=tflite_bytes)
interp.allocate_tensors()
inp = interp.get_input_details()[0]
out = interp.get_output_details()[0]
print(f"TFLite in:  {inp['shape']}  dtype={inp['dtype']}")
print(f"TFLite out: {out['shape']}  dtype={out['dtype']}")
