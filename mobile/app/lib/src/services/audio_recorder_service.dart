import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

/// Service to handle audio recording with proper buffering
class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _recordSubscription;
  StreamController<Uint8List>? _audioStreamController;
  
  bool _isRecording = false;
  bool get isRecording => _isRecording;

  /// Start recording audio and return a stream of audio data
  Future<Stream<Uint8List>> startRecording({
    required int sampleRate,
    required Function(RecordState) onStateChanged,
  }) async {
    if (_isRecording) {
      throw Exception('Already recording');
    }

    // Check permission
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw Exception('Microphone permission not granted');
    }

    // Create stream controller
    _audioStreamController = StreamController<Uint8List>.broadcast();

    try {
      // Start recording with PCM16 format
      final stream = await _recorder.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: sampleRate,
          numChannels: 1,
          bitRate: sampleRate * 16, // 16 bits per sample
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
        ),
      );

      // Listen to state changes
      _recorder.onStateChanged().listen(onStateChanged);

      // Forward audio data with buffering
      final buffer = <int>[];
      const bufferSize = 4800; // 100ms at 24kHz
      
      _recordSubscription = stream.listen(
        (data) {
          buffer.addAll(data);
          
          // Send chunks when buffer is full
          while (buffer.length >= bufferSize) {
            final chunk = buffer.take(bufferSize).toList();
            buffer.removeRange(0, bufferSize);
            _audioStreamController?.add(Uint8List.fromList(chunk));
          }
        },
        onError: (error) {
          debugPrint('Recording error: $error');
          _audioStreamController?.addError(error);
        },
        onDone: () {
          // Send any remaining data
          if (buffer.isNotEmpty) {
            _audioStreamController?.add(Uint8List.fromList(buffer));
          }
          _audioStreamController?.close();
        },
      );

      _isRecording = true;
      return _audioStreamController!.stream;
    } catch (e) {
      _audioStreamController?.close();
      rethrow;
    }
  }

  /// Stop recording
  Future<void> stopRecording() async {
    if (!_isRecording) return;

    await _recordSubscription?.cancel();
    await _recorder.stop();
    await _audioStreamController?.close();
    
    _recordSubscription = null;
    _audioStreamController = null;
    _isRecording = false;
  }

  /// Pause recording
  Future<void> pauseRecording() async {
    if (_isRecording) {
      await _recorder.pause();
    }
  }

  /// Resume recording
  Future<void> resumeRecording() async {
    if (_isRecording) {
      await _recorder.resume();
    }
  }

  /// Check if recording is paused
  Future<bool> isPaused() async {
    return await _recorder.isPaused();
  }

  /// Get current amplitude (0.0 to 1.0)
  Future<double> getAmplitude() async {
    final amplitude = await _recorder.getAmplitude();
    return amplitude.current;
  }

  /// Dispose of resources
  void dispose() {
    stopRecording();
    _recorder.dispose();
  }
}
