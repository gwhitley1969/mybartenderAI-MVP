import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Service for handling Speech-to-Text functionality using device STT
/// (Can be upgraded to Azure STT in the future for better accuracy)
class SpeechService {
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
  bool _isInitialized = false;

  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;

  /// Initialize the speech recognition service
  Future<bool> initialize() async {
    try {
      // Request microphone permission
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        debugPrint('Microphone permission denied');
        return false;
      }

      // Initialize speech recognition
      _isInitialized = await _speech.initialize(
        onError: (error) {
          debugPrint('Speech recognition error: ${error.errorMsg}');
        },
        onStatus: (status) {
          debugPrint('Speech recognition status: $status');
        },
      );

      if (_isInitialized) {
        debugPrint('Speech recognition initialized successfully');
      } else {
        debugPrint('Speech recognition initialization failed');
      }

      return _isInitialized;
    } catch (e) {
      debugPrint('Error initializing speech recognition: $e');
      return false;
    }
  }

  /// Start listening for speech input
  /// Returns a stream of recognized words
  Future<void> listen({
    required Function(String) onResult,
    Function(String)? onPartialResult,
    Duration listenFor = const Duration(seconds: 30),
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    if (!_isInitialized) {
      debugPrint('Speech recognition not initialized');
      return;
    }

    if (_isListening) {
      debugPrint('Already listening');
      return;
    }

    _isListening = true;

    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          onResult(result.recognizedWords);
        } else if (onPartialResult != null) {
          onPartialResult(result.recognizedWords);
        }
      },
      listenFor: listenFor,
      pauseFor: pauseFor,
      partialResults: onPartialResult != null,
      localeId: 'en_US',
      listenMode: ListenMode.dictation,
      // Custom vocabulary for bartending terms (if supported)
      onSoundLevelChange: (level) {
        // Can be used for UI feedback (mic volume indicator)
      },
    );
  }

  /// Stop listening for speech input
  Future<void> stop() async {
    if (!_isListening) return;

    await _speech.stop();
    _isListening = false;
    debugPrint('Stopped listening');
  }

  /// Cancel listening (immediate stop without processing)
  Future<void> cancel() async {
    if (!_isListening) return;

    await _speech.cancel();
    _isListening = false;
    debugPrint('Cancelled listening');
  }

  /// Get available locales for speech recognition
  Future<List<String>> getAvailableLocales() async {
    if (!_isInitialized) {
      await initialize();
    }

    final locales = await _speech.locales();
    return locales.map((locale) => locale.localeId).toList();
  }

  /// Check if speech recognition is available on this device
  Future<bool> isAvailable() async {
    return await _speech.initialize();
  }

  /// Dispose of the speech recognition service
  void dispose() {
    _speech.stop();
  }
}
