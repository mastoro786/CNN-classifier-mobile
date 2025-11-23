import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

/// Service for loading and processing audio files
class AudioFileService {
  /// Pick audio file from device storage
  Future<File?> pickAudioFile() async {
    try {
      print('📁 Opening file picker...');
      
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['wav', 'ogg'],
        allowMultiple: false,
      );
      
      if (result == null || result.files.isEmpty) {
        print('❌ No file selected');
        return null;
      }
      
      final filePath = result.files.first.path;
      if (filePath == null) {
        print('❌ Invalid file path');
        return null;
      }
      
      final file = File(filePath);
      final exists = await file.exists();
      
      if (!exists) {
        print('❌ File does not exist');
        return null;
      }
      
      final fileName = result.files.first.name;
      final fileSize = await file.length();
      
      print('✅ File selected:');
      print('   Name: $fileName');
      print('   Path: $filePath');
      print('   Size: ${(fileSize / 1024).toStringAsFixed(2)} KB');
      
      return file;
    } catch (e) {
      print('❌ Error picking file: $e');
      rethrow;
    }
  }
  
  /// Load audio file and convert to Float32List
  Future<Float32List?> loadAudioFile(File file) async {
    try {
      print('📂 Loading audio file...');
      
      final bytes = await file.readAsBytes();
      final extension = file.path.split('.').last.toLowerCase();
      
      print('   File format: $extension');
      print('   File size: ${bytes.length} bytes');
      
      // Convert based on file format
      Float32List? audioSamples;
      
      if (extension == 'wav') {
        audioSamples = _loadWavFile(bytes);
      } else if (extension == 'ogg') {
        // OGG Vorbis requires decoding
        // For now, we'll throw an error and suggest using WAV
        throw UnsupportedError(
          'OGG format requires additional decoder. Please convert to WAV format or use recording feature.',
        );
      } else {
        throw UnsupportedError('Unsupported audio format: $extension');
      }
      
      print('✅ Audio loaded successfully');
      print('   Samples: ${audioSamples.length}');
      print('   Duration: ${(audioSamples.length / 22050).toStringAsFixed(2)}s');
      
      return audioSamples;
    } catch (e) {
      print('❌ Error loading audio file: $e');
      rethrow;
    }
  }
  
  /// Load WAV file and convert to Float32List
  Float32List _loadWavFile(Uint8List bytes) {
    try {
      // Parse WAV header
      if (bytes.length < 44) {
        throw FormatException('Invalid WAV file: too short');
      }
      
      // Check RIFF header
      final riffHeader = String.fromCharCodes(bytes.sublist(0, 4));
      if (riffHeader != 'RIFF') {
        throw FormatException('Invalid WAV file: missing RIFF header');
      }
      
      // Check WAVE format
      final waveFormat = String.fromCharCodes(bytes.sublist(8, 12));
      if (waveFormat != 'WAVE') {
        throw FormatException('Invalid WAV file: missing WAVE format');
      }
      
      // Find data chunk
      int dataOffset = 12;
      int dataSize = 0;
      
      while (dataOffset < bytes.length - 8) {
        final chunkId = String.fromCharCodes(bytes.sublist(dataOffset, dataOffset + 4));
        final chunkSize = _readInt32(bytes, dataOffset + 4);
        
        if (chunkId == 'data') {
          dataSize = chunkSize;
          dataOffset += 8;
          break;
        }
        
        dataOffset += 8 + chunkSize;
      }
      
      if (dataSize == 0) {
        throw FormatException('Invalid WAV file: no data chunk found');
      }
      
      print('   WAV data chunk found at offset $dataOffset, size: $dataSize bytes');
      
      // Extract PCM data
      final pcmData = bytes.sublist(dataOffset, dataOffset + dataSize);
      
      // Assume 16-bit PCM (2 bytes per sample)
      final numSamples = pcmData.length ~/ 2;
      final Float32List samples = Float32List(numSamples);
      
      for (int i = 0; i < numSamples; i++) {
        // Read 16-bit signed integer (little-endian)
        final byte1 = pcmData[i * 2];
        final byte2 = pcmData[i * 2 + 1];
        final int16Value = (byte2 << 8) | byte1;
        
        // Convert to signed
        final signedValue = int16Value > 32767 ? int16Value - 65536 : int16Value;
        
        // Normalize to [-1.0, 1.0]
        samples[i] = signedValue / 32768.0;
      }
      
      return samples;
    } catch (e) {
      print('❌ Error parsing WAV file: $e');
      rethrow;
    }
  }
  
  /// Read 32-bit integer from bytes (little-endian)
  int _readInt32(Uint8List bytes, int offset) {
    return bytes[offset] |
           (bytes[offset + 1] << 8) |
           (bytes[offset + 2] << 16) |
           (bytes[offset + 3] << 24);
  }
  
  /// Validate audio file format and duration
  Future<bool> validateAudioFile(File file) async {
    try {
      final extension = file.path.split('.').last.toLowerCase();
      
      // Check file extension
      if (extension != 'wav' && extension != 'ogg') {
        print('❌ Invalid file format: $extension');
        return false;
      }
      
      // Check file size (max 10 MB)
      final fileSize = await file.length();
      if (fileSize > 10 * 1024 * 1024) {
        print('❌ File too large: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
        return false;
      }
      
      return true;
    } catch (e) {
      print('❌ Error validating file: $e');
      return false;
    }
  }
}
