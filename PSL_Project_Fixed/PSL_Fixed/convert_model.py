"""
PSL Urdu Model Converter
========================
Converts hand_landmark_nn.h5 (Keras) → hand_landmark_nn.tflite (TFLite for Android)

Usage:
    pip install tensorflow
    python convert_model.py

Place the output .tflite file in: psl_urdu_app/assets/models/
"""

import os
import sys

def convert_model(h5_path='hand_landmark_nn.h5', output_path='hand_landmark_nn.tflite'):
    try:
        import tensorflow as tf
        print(f"TensorFlow version: {tf.__version__}")
    except ImportError:
        print("❌ TensorFlow not installed. Run: pip install tensorflow")
        sys.exit(1)

    if not os.path.exists(h5_path):
        print(f"❌ Model file not found: {h5_path}")
        print("   Place hand_landmark_nn.h5 in the same folder as this script.")
        sys.exit(1)

    print(f"📂 Loading model: {h5_path}")
    model = tf.keras.models.load_model(h5_path)

    print(f"📊 Model summary:")
    model.summary()

    print(f"\n🔄 Converting to TFLite...")

    # Standard conversion
    converter = tf.lite.TFLiteConverter.from_keras_model(model)

    # Optimization for mobile (reduces size ~4x, minimal accuracy loss)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]

    # Optional: Full integer quantization (even smaller, needs representative dataset)
    # Uncomment if you want this:
    # def representative_data_gen():
    #     import numpy as np
    #     for _ in range(100):
    #         yield [np.random.randn(1, 63).astype(np.float32)]
    # converter.representative_dataset = representative_data_gen
    # converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
    # converter.inference_input_type = tf.int8
    # converter.inference_output_type = tf.int8

    tflite_model = converter.convert()

    with open(output_path, 'wb') as f:
        f.write(tflite_model)

    size_kb = len(tflite_model) / 1024
    print(f"\n✅ Conversion successful!")
    print(f"   Output: {output_path}")
    print(f"   Size: {size_kb:.1f} KB")
    print(f"\n📋 Next steps:")
    print(f"   1. Copy '{output_path}' to 'psl_urdu_app/assets/models/'")
    print(f"   2. Run: flutter pub get")
    print(f"   3. Run: flutter build apk --release")

    # Also verify the model works
    print(f"\n🧪 Verifying model...")
    interpreter = tf.lite.Interpreter(model_path=output_path)
    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    print(f"   Input shape: {input_details[0]['shape']} (expected: [1, 63])")
    print(f"   Output shape: {output_details[0]['shape']} (expected: [1, num_classes])")

    return output_path


if __name__ == '__main__':
    h5_path = sys.argv[1] if len(sys.argv) > 1 else 'hand_landmark_nn.h5'
    convert_model(h5_path)
