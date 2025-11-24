# verify_tflite_conversion.py

import tensorflow as tf
import numpy as np
import librosa
from app_optimized import extract_mel_spectrogram

# Load both models
keras_model = tf.keras.models.load_model('models/best_model.h5')
tflite_model_path = 'assets/models/audio_classifier.tflite'

# Load TFLite interpreter
interpreter = tf.lite.Interpreter(model_path=tflite_model_path)
interpreter.allocate_tensors()

input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

# Test audio
audio, sr = librosa.load('normal_nathan_03.wav', sr=22050)
mel_spec = extract_mel_spectrogram(audio, sr)
input_data = mel_spec[np.newaxis, ..., np.newaxis].astype(np.float32)

# Keras prediction
keras_pred = keras_model.predict(input_data, verbose=0)

# TFLite prediction
interpreter.set_tensor(input_details[0]['index'], input_data)
interpreter.invoke()
tflite_pred = interpreter.get_tensor(output_details[0]['index'])

print("="*60)
print("CONVERSION VERIFICATION")
print("="*60)
print(f"Input shape: {input_data.shape}")
print(f"Input min: {input_data.min():.2f}")
print(f"Input max: {input_data.max():.2f}")
print()
print(f"Keras output: {keras_pred[0][0]:.6f}")
print(f"TFLite output: {tflite_pred[0][0]:.6f}")
print(f"Difference: {abs(keras_pred[0][0] - tflite_pred[0][0]):.6f}")
print()

if abs(keras_pred[0][0] - tflite_pred[0][0]) > 0.01:
    print("❌ CONVERSION ERROR DETECTED!")
    print("   Keras and TFLite outputs don't match!")
    print("   Need to re-convert model!")
else:
    print("✅ Conversion OK")
print("="*60)