import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';

/// Provider for Speech-to-Text service
final speechServiceProvider = Provider<SpeechService>((ref) {
  return SpeechService();
});

/// Provider for Text-to-Speech service
final ttsServiceProvider = Provider<TTSService>((ref) {
  return TTSService();
});
