import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// Handles audio streaming for the Realtime API
class AudioStreamHandler {
  static const int sampleRate = 24000;
  static const int channels = 1;
  static const int bitsPerSample = 16;
  
  // Buffer for outgoing audio chunks
  final List<int> _outgoingBuffer = [];
  
  // Buffer for incoming audio data
  final List<int> _incomingBuffer = [];
  
  // Stream controller for processed audio
  final _audioStreamController = StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get audioStream => _audioStreamController.stream;
  
  // Timer for sending audio chunks
  Timer? _sendTimer;
  
  // Callback for sending audio data
  Function(String)? onSendAudio;

  /// Start processing audio stream
  void startStreaming() {
    // Send audio chunks every 100ms
    _sendTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _sendBufferedAudio();
    });
  }

  /// Stop processing audio stream
  void stopStreaming() {
    _sendTimer?.cancel();
    _sendTimer = null;
    _outgoingBuffer.clear();
    _incomingBuffer.clear();
  }

  /// Add audio data to outgoing buffer
  void addAudioData(Uint8List audioData) {
    _outgoingBuffer.addAll(audioData);
  }

  /// Send buffered audio data
  void _sendBufferedAudio() {
    if (_outgoingBuffer.isEmpty || onSendAudio == null) return;
    
    // OpenAI expects chunks of a reasonable size
    const chunkSize = 4800; // 100ms of audio at 24kHz, 16-bit mono
    
    while (_outgoingBuffer.length >= chunkSize) {
      final chunk = _outgoingBuffer.take(chunkSize).toList();
      _outgoingBuffer.removeRange(0, chunkSize);
      
      // Convert to base64 and send
      final base64Audio = base64Encode(Uint8List.fromList(chunk));
      onSendAudio!(base64Audio);
    }
  }

  /// Handle incoming audio delta from the API
  void handleAudioDelta(String base64Audio) {
    try {
      final audioBytes = base64Decode(base64Audio);
      _incomingBuffer.addAll(audioBytes);
      
      // Process in chunks for smoother playback
      const chunkSize = 2400; // 50ms of audio
      while (_incomingBuffer.length >= chunkSize) {
        final chunk = _incomingBuffer.take(chunkSize).toList();
        _incomingBuffer.removeRange(0, chunkSize);
        _audioStreamController.add(Uint8List.fromList(chunk));
      }
    } catch (e) {
      debugPrint('Error processing audio delta: $e');
    }
  }

  /// Create WAV header for PCM16 data
  static Uint8List createWavHeader(int dataSize) {
    final header = ByteData(44);
    
    // RIFF header
    header.setUint8(0, 0x52); // 'R'
    header.setUint8(1, 0x49); // 'I'
    header.setUint8(2, 0x46); // 'F'
    header.setUint8(3, 0x46); // 'F'
    header.setUint32(4, dataSize + 36, Endian.little);
    header.setUint8(8, 0x57); // 'W'
    header.setUint8(9, 0x41); // 'A'
    header.setUint8(10, 0x56); // 'V'
    header.setUint8(11, 0x45); // 'E'
    
    // fmt chunk
    header.setUint8(12, 0x66); // 'f'
    header.setUint8(13, 0x6D); // 'm'
    header.setUint8(14, 0x74); // 't'
    header.setUint8(15, 0x20); // ' '
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little); // PCM
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * channels * bitsPerSample ~/ 8, Endian.little);
    header.setUint16(32, channels * bitsPerSample ~/ 8, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    
    // data chunk
    header.setUint8(36, 0x64); // 'd'
    header.setUint8(37, 0x61); // 'a'
    header.setUint8(38, 0x74); // 't'
    header.setUint8(39, 0x61); // 'a'
    header.setUint32(40, dataSize, Endian.little);
    
    return header.buffer.asUint8List();
  }

  /// Convert PCM16 data to WAV format
  static Uint8List pcm16ToWav(List<int> pcmData) {
    final header = createWavHeader(pcmData.length);
    final wavData = Uint8List(44 + pcmData.length);
    wavData.setRange(0, 44, header);
    wavData.setRange(44, 44 + pcmData.length, pcmData);
    return wavData;
  }

  /// Flush any remaining audio data
  void flush() {
    if (_incomingBuffer.isNotEmpty) {
      _audioStreamController.add(Uint8List.fromList(_incomingBuffer));
      _incomingBuffer.clear();
    }
  }

  void dispose() {
    stopStreaming();
    _audioStreamController.close();
  }
}
