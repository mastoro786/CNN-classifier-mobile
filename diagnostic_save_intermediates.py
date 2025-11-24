#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Diagnostic Script: Save Intermediate Preprocessing Values
For comparing Python vs Flutter preprocessing
"""

import sys
import librosa
import numpy as np

# Configuration
N_MELS = 128
FMAX = 8000
MAX_LEN = 216
SAMPLE_RATE = 22050

# Get audio file
if len(sys.argv) > 1:
    audio_file = sys.argv[1]
else:
    audio_file = 'data_uji/normal_nathan_03.wav'

print("="*60)
print("PREPROCESSING DIAGNOSTIC")
print("="*60)
print(f"Audio file: {audio_file}\n")

# Load audio
audio, sr = librosa.load(audio_file, sr=SAMPLE_RATE)
print(f"1. Audio loaded:")
print(f"   Samples: {len(audio)}")
print(f"   Duration: {len(audio)/sr:.2f}s")
print(f"   Min: {audio.min():.6f}")
print(f"   Max: {audio.max():.6f}")
print(f"   Mean: {audio.mean():.6f}")

# STFT
print(f"\n2. Computing STFT...")
stft = librosa.stft(audio, n_fft=2048, hop_length=512, center=True)
print(f"   Shape: {stft.shape}")
print(f"   Complex type: {stft.dtype}")

# Check magnitude
magnitude = np.abs(stft)
print(f"\n3. STFT Magnitude:")
print(f"   Max: {magnitude.max():.4f}")
print(f"   Mean: {magnitude.mean():.4f}")
print(f"   Min: {magnitude.min():.4f}")

# Power spectrum
power = magnitude ** 2
print(f"\n4. Power Spectrum (magnitude²):")
print(f"   Max: {power.max():.4f}")
print(f"   Mean: {power.mean():.4f}")
print(f"   First frame max: {power[:, 0].max():.4f}")

# Mel filterbank
print(f"\n5. Creating Mel filterbank...")
mel_filters = librosa.filters.mel(
    sr=SAMPLE_RATE,
    n_fft=2048,
    n_mels=N_MELS,
    fmin=0.0,
    fmax=FMAX,
    norm=None  # No normalization
)
print(f"   Shape: {mel_filters.shape}")
print(f"   Filter max: {mel_filters.max():.6f}")
print(f"   Filter sum (filter 0): {mel_filters[0].sum():.6f}")

# Apply mel filterbank
mel_spec = np.dot(mel_filters, power)
print(f"\n6. Mel Spectrogram (power):")
print(f"   Shape: {mel_spec.shape}")
print(f"   Max: {mel_spec.max():.4f}")
print(f"   Mean: {mel_spec.mean():.4f}")
print(f"   Min: {mel_spec.min():.4f}")

# Power to dB
mel_spec_db = librosa.power_to_db(mel_spec, ref=np.max)
print(f"\n7. Mel Spectrogram (dB):")
print(f"   Max: {mel_spec_db.max():.2f} dB")
print(f"   Mean: {mel_spec_db.mean():.2f} dB")
print(f"   Min: {mel_spec_db.min():.2f} dB")

# Pad/truncate
if mel_spec_db.shape[1] < MAX_LEN:
    pad_width = MAX_LEN - mel_spec_db.shape[1]
    mel_spec_db = np.pad(mel_spec_db, pad_width=((0, 0), (0, pad_width)), mode='constant')
    print(f"\n8. After padding:")
else:
    mel_spec_db = mel_spec_db[:, :MAX_LEN]
    print(f"\n8. After truncating:")

print(f"   Shape: {mel_spec_db.shape}")
print(f"   Mean: {mel_spec_db.mean():.2f} dB ← COMPARE WITH FLUTTER!")

# Save intermediate values
print(f"\n9. Saving intermediate values...")
np.save('debug_audio.npy', audio[:1000])
np.save('debug_power.npy', power[:10, :10])  # First 10x10
np.save('debug_mel_spec.npy', mel_spec[:, :10])  # First 10 frames
np.save('debug_mel_db.npy', mel_spec_db[:, :10])  # First 10 frames

print(f"   ✅ Saved:")
print(f"      - debug_audio.npy (first 1000 samples)")
print(f"      - debug_power.npy (10x10 STFT power)")
print(f"      - debug_mel_spec.npy (128x10 mel power)")
print(f"      - debug_mel_db.npy (128x10 mel dB)")

# Print first 10 values for easy comparison
print(f"\n10. First 10 dB values (mel band 0, for comparison):")
print(f"    {mel_spec_db[0, :10]}")

print("\n" + "="*60)
print("COMPARISON WITH FLUTTER:")
print("="*60)
print(f"Expected Flutter 'Input mean': {mel_spec_db.mean():.2f} dB")
print(f"Expected Flutter 'Power max': {power.max():.4f}")
print(f"Expected Flutter 'Mel spec max': {mel_spec.max():.4f}")
print("\nIf Flutter values are DIFFERENT:")
print("  - Power max different → STFT computation wrong")
print("  - Mel spec different → Mel filterbank wrong")  
print("  - Mean dB different → Conversion or normalization wrong")
print("="*60)
