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
        type: FileType.any,
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
        throw const FormatException('Invalid WAV file: too short');
      }
      
      // Check RIFF header
      final riffHeader = String.fromCharCodes(bytes.sublist(0, 4));
      if (riffHeader != 'RIFF') {
        throw const FormatException('Invalid WAV file: missing RIFF header');
      }
      
      // Check WAVE format
      final waveFormat = String.fromCharCodes(bytes.sublist(8, 12));
      if (waveFormat != 'WAVE') {
        throw const FormatException('Invalid WAV file: missing WAVE format');
      }
      
      // Parse fmt chunk to get audio format info
      int numChannels = 1;
      int sampleRate = 22050;
      int bitsPerSample = 16;
      int dataOffset = 12;
      int dataSize = 0;
      
      while (dataOffset < bytes.length - 8) {
        final chunkId = String.fromCharCodes(bytes.sublist(dataOffset, dataOffset + 4));
        final chunkSize = _readInt32(bytes, dataOffset + 4);
        
        if (chunkId == 'fmt ') {
          // Read audio format parameters
          // audioFormat = bytes[dataOffset + 8] | (bytes[dataOffset + 9] << 8); // 1 = PCM
          numChannels = bytes[dataOffset + 10] | (bytes[dataOffset + 11] << 8);
          sampleRate = _readInt32(bytes, dataOffset + 12);
          bitsPerSample = bytes[dataOffset + 22] | (bytes[dataOffset + 23] << 8);
          
          print('   WAV fmt: $numChannels channels, $sampleRate Hz, $bitsPerSample bits');
        } else if (chunkId == 'data') {
          dataSize = chunkSize;
          dataOffset += 8;
          break;
        }
        
        dataOffset += 8 + chunkSize;
      }
      
      if (dataSize == 0) {
        throw const FormatException('Invalid WAV file: no data chunk found');
      }
      
      print('   WAV data chunk found at offset $dataOffset, size: $dataSize bytes');
      
      // Extract PCM data
      final pcmData = bytes.sublist(dataOffset, dataOffset + dataSize);
      
      // Calculate number of samples per channel
      final bytesPerSample = bitsPerSample ~/ 8;
      final totalSamples = pcmData.length ~/ bytesPerSample;
      final samplesPerChannel = totalSamples ~/ numChannels;
      
      // Read and convert to float, handling stereo by averaging channels
      final Float32List monoSamples = Float32List(samplesPerChannel);
      
      if (numChannels == 1) {
        // Mono: direct conversion
        for (int i = 0; i < samplesPerChannel; i++) {
          final byte1 = pcmData[i * 2];
          final byte2 = pcmData[i * 2 + 1];
          final int16Value = (byte2 << 8) | byte1;
          final signedValue = int16Value > 32767 ? int16Value - 65536 : int16Value;
          monoSamples[i] = signedValue / 32768.0;
        }
      } else if (numChannels == 2) {
        // Stereo: average left and right channels (matching librosa mono=True)
        for (int i = 0; i < samplesPerChannel; i++) {
          // Read left channel
          final leftByte1 = pcmData[i * 4];
          final leftByte2 = pcmData[i * 4 + 1];
          final leftInt16 = (leftByte2 << 8) | leftByte1;
          final leftSigned = leftInt16 > 32767 ? leftInt16 - 65536 : leftInt16;
          final leftFloat = leftSigned / 32768.0;
          
          // Read right channel
          final rightByte1 = pcmData[i * 4 + 2];
          final rightByte2 = pcmData[i * 4 + 3];
          final rightInt16 = (rightByte2 << 8) | rightByte1;
          final rightSigned = rightInt16 > 32767 ? rightInt16 - 65536 : rightInt16;
          final rightFloat = rightSigned / 32768.0;
          
          // Average channels
          monoSamples[i] = (leftFloat + rightFloat) / 2.0;
        }
      } else {
        throw UnsupportedError('Only mono and stereo audio supported, got $numChannels channels');
      }
      
      // Resample to 22050 Hz if needed (matching librosa sr=22050)
      final Float32List resampledSamples;
      if (sampleRate == 22050) {
        resampledSamples = monoSamples;
      } else {
        resampledSamples = _resample(monoSamples, sampleRate, 22050);
        print('   Resampled from $sampleRate Hz to 22050 Hz');
      }
      
      return resampledSamples;
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
  
  /// Resample audio to target sample rate using linear interpolation
  /// This matches librosa.resample() basic behavior for sr=22050
  Float32List _resample(Float32List input, int fromRate, int toRate) {
    if (fromRate == toRate) return input;
    
    final double ratio = toRate / fromRate;
    final int outputLength = (input.length * ratio).round();
    final Float32List output = Float32List(outputLength);
    
    for (int i = 0; i < outputLength; i++) {
      // Calculate position in input array
      final double position = i / ratio;
      final int index = position.floor();
      final double fraction = position - index;
      
      if (index + 1 < input.length) {
        // Linear interpolation between two samples
        output[i] = input[index] * (1.0 - fraction) + input[index + 1] * fraction;
      } else {
        // Last sample, no interpolation
        output[i] = input[index];
      }
    }
    
    return output;
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
