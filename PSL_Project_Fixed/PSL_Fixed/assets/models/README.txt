Place your TFLite model here:
  hand_landmark_nn.tflite

Convert from your Keras .h5 model using:
  python convert_model.py hand_landmark_nn.h5

The model input should be: shape [1, 63] (21 landmarks × 3 coordinates)
The model output should be: shape [1, 36] (36 Urdu alphabet classes)
