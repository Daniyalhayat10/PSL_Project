"""
Rebuilds hand_landmark_nn from raw HDF5 weights (bypasses broken Keras config
deserialization) and converts to a clean float32 TFLite model.
Architecture read from h5py inspection:
  Input(63) -> Dense(256,relu) -> Drop(0.3) -> Dense(128,relu) -> Drop(0.3)
             -> Dense(64,relu) -> Drop(0.2) -> Dense(37,softmax)
"""
import h5py
import numpy as np
import tensorflow as tf

H5  = r"D:\dannything_project\PSL_Project\PSL_Project_Fixed\PSL_Fixed\assets\models\hand_landmark_nn.h5"
OUT = r"D:\dannything_project\PSL_Project\PSL_Project_Fixed\PSL_Fixed\assets\models\hand_landmark_nn.tflite"

print(f"TF {tf.__version__}")

# ── Read weights from h5 ──────────────────────────────────────────────────────
with h5py.File(H5, 'r') as f:
    mw = f['model_weights']
    w0_k = np.array(mw['dense/sequential/dense/kernel'])
    w0_b = np.array(mw['dense/sequential/dense/bias'])
    w1_k = np.array(mw['dense_1/sequential/dense_1/kernel'])
    w1_b = np.array(mw['dense_1/sequential/dense_1/bias'])
    w2_k = np.array(mw['dense_2/sequential/dense_2/kernel'])
    w2_b = np.array(mw['dense_2/sequential/dense_2/bias'])
    w3_k = np.array(mw['dense_3/sequential/dense_3/kernel'])
    w3_b = np.array(mw['dense_3/sequential/dense_3/bias'])

print(f"Weights loaded: {w0_k.shape} {w1_k.shape} {w2_k.shape} {w3_k.shape}")

# ── Rebuild model ─────────────────────────────────────────────────────────────
model = tf.keras.Sequential([
    tf.keras.layers.Input(shape=(63,)),
    tf.keras.layers.Dense(256, activation='relu'),
    tf.keras.layers.Dropout(0.3),
    tf.keras.layers.Dense(128, activation='relu'),
    tf.keras.layers.Dropout(0.3),
    tf.keras.layers.Dense(64, activation='relu'),
    tf.keras.layers.Dropout(0.2),
    tf.keras.layers.Dense(37, activation='softmax'),
])
model.layers[0].set_weights([w0_k, w0_b])
model.layers[2].set_weights([w1_k, w1_b])
model.layers[4].set_weights([w2_k, w2_b])
model.layers[6].set_weights([w3_k, w3_b])

# Quick sanity check: feed a non-zero input and see if output varies
x = np.random.randn(1, 63).astype(np.float32)
y = model(x, training=False).numpy()
print(f"Sanity (random input): max={y.max():.4f} min={y.min():.4f} argmax={y.argmax()}")

# ── Convert to TFLite (no quantization) ──────────────────────────────────────
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS]
converter.optimizations = []   # float32 — keeps FC at v9, no patch needed

tflite_bytes = converter.convert()

with open(OUT, 'wb') as f:
    f.write(tflite_bytes)

print(f"Saved {len(tflite_bytes):,} bytes -> {OUT}")

# Verify
interp = tf.lite.Interpreter(model_content=tflite_bytes)
interp.allocate_tensors()
inp_d = interp.get_input_details()[0]
out_d = interp.get_output_details()[0]
print(f"TFLite in : {inp_d['shape']} dtype={inp_d['dtype'].__name__}")
print(f"TFLite out: {out_d['shape']} dtype={out_d['dtype'].__name__}")

interp.set_tensor(inp_d['index'], x)
interp.invoke()
y2 = interp.get_tensor(out_d['index'])
print(f"TFLite out (random):  max={y2.max():.4f} argmax={y2.argmax()}")
print(f"Keras  out (random):  max={y.max():.4f} argmax={y.argmax()}")
print("Match:", np.allclose(y, y2, atol=1e-5))
