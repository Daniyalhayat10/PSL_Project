import tensorflow as tf
print("TF version:", tf.__version__)

H5 = r"D:\dannything_project\PSL_Project\PSL_Project_Fixed\PSL_Fixed\assets\models\hand_landmark_nn.h5"
OUT = r"D:\dannything_project\PSL_Project\PSL_Project_Fixed\PSL_Fixed\assets\models\hand_landmark_nn.tflite"

model = tf.keras.models.load_model(H5)
print("Input:", model.input_shape, "Output:", model.output_shape)

converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS]
converter.optimizations = []           # no quantization — keeps ops at lowest version
tflite_bytes = converter.convert()

with open(OUT, "wb") as f:
    f.write(tflite_bytes)

print(f"Saved {len(tflite_bytes):,} bytes → {OUT}")
