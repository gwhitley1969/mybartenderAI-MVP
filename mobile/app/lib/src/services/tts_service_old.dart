import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Service for handling Text-to-Speech functionality
/// Uses device TTS (can be upgraded to Azure Neural TTS in the future)
class TTSService {
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;

  bool get isInitialized => _isInitialized;
  bool get isSpeaking => _isSpeaking;

  /// Initialize the TTS service
  Future<void> initialize() async {
    try {
      // Set up TTS callbacks
      _tts.setStartHandler(() {
        _isSpeaking = true;
        debugPrint('TTS: Started speaking');
      });

      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        debugPrint('TTS: Completed speaking');
      });

      _tts.setProgressHandler((text, start, end, word) {
        debugPrint('TTS: Speaking word: $word');
      });

      _tts.setErrorHandler((message) {
        _isSpeaking = false;
        debugPrint('TTS Error: $message');
      });

      _tts.setCancelHandler(() {
        _isSpeaking = false;
        debugPrint('TTS: Cancelled');
      });

      // Configure voice settings optimized for cocktail instructions
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5); // Slower for clear instructions
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      // Try to set a pleasant voice if available
      // On iOS: Use "com.apple.ttsbundle.Samantha-compact" or similar
      // On Android: Use system default or Google TTS voices
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _tts.setVoice({'name': 'Samantha', 'locale': 'en-US'});
      }

      _isInitialized = true;
      debugPrint('TTS initialized successfully');
    } catch (e) {
      debugPrint('Error initializing TTS: $e');
    }
  }

  /// Speak the given text
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (text.isEmpty) {
      debugPrint('TTS: Empty text, nothing to speak');
      return;
    }

    try {
      await _tts.speak(text);
    } catch (e) {
      debugPrint('Error speaking: $e');
    }
  }

  /// Stop speaking immediately
  Future<void> stop() async {
    if (!_isSpeaking) return;

    try {
      await _tts.stop();
      _isSpeaking = false;
    } catch (e) {
      debugPrint('Error stopping TTS: $e');
    }
  }

  /// Pause speaking
  Future<void> pause() async {
    if (!_isSpeaking) return;

    try {
      await _tts.pause();
    } catch (e) {
      debugPrint('Error pausing TTS: $e');
    }
  }

  /// Set speech rate (0.0 to 1.0, where 0.5 is normal)
  Future<void> setSpeechRate(double rate) async {
    try {
      await _tts.setSpeechRate(rate.clamp(0.0, 1.0));
    } catch (e) {
      debugPrint('Error setting speech rate: $e');
    }
  }

  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    try {
      await _tts.setVolume(volume.clamp(0.0, 1.0));
    } catch (e) {
      debugPrint('Error setting volume: $e');
    }
  }

  /// Set pitch (0.5 to 2.0, where 1.0 is normal)
  Future<void> setPitch(double pitch) async {
    try {
      await _tts.setPitch(pitch.clamp(0.5, 2.0));
    } catch (e) {
      debugPrint('Error setting pitch: $e');
    }
  }

  /// Get available voices
  Future<List<Map<String, String>>> getVoices() async {
    try {
      final voices = await _tts.getVoices;
      return List<Map<String, String>>.from(voices ?? []);
    } catch (e) {
      debugPrint('Error getting voices: $e');
      return [];
    }
  }

  /// Set voice by name and locale
  Future<void> setVoice(String name, String locale) async {
    try {
      await _tts.setVoice({'name': name, 'locale': locale});
    } catch (e) {
      debugPrint('Error setting voice: $e');
    }
  }

  /// Get available languages
  Future<List<String>> getLanguages() async {
    try {
      final languages = await _tts.getLanguages;
      return List<String>.from(languages ?? []);
    } catch (e) {
      debugPrint('Error getting languages: $e');
      return [];
    }
  }

  /// Speak with emphasis on specific words
  /// Example: speakWithEmphasis("Add two ounces of gin", ["two ounces"])
  Future<void> speakWithEmphasis(String text, List<String> emphasize) async {
    // For basic TTS, we'll just speak the text as-is
    // In the future with Azure Neural TTS, we can use SSML for emphasis
    // Example SSML: "<speak>Add <emphasis>two ounces</emphasis> of gin</speak>"
    await speak(text);
  }

  /// Check if TTS is available on this device
  Future<bool> isAvailable() async {
    try {
      final languages = await _tts.getLanguages;
      return languages != null && languages.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Dispose of the TTS service
  void dispose() {
    _tts.stop();
  }
}
