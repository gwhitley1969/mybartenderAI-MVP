import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/voice_ai_service.dart';
import 'backend_provider.dart';
import 'auth_provider.dart';

/// Provider for Voice AI service
final voiceAIServiceProvider = Provider<VoiceAIService>((ref) {
  final backendService = ref.watch(backendServiceProvider);
  return VoiceAIService(
    backendService.dio,
    getUserId: () async {
      // Get current user ID from auth state
      final user = ref.read(currentUserProvider);
      return user?.id;
    },
  );
});

/// Provider for voice quota check
final voiceQuotaProvider = FutureProvider<VoiceQuota>((ref) async {
  final voiceService = ref.watch(voiceAIServiceProvider);
  return await voiceService.getVoiceQuota();
});

/// Notifier class for managing voice AI state
class VoiceAINotifier extends StateNotifier<VoiceAISessionState> {
  final VoiceAIService _service;
  final Ref _ref;

  VoiceAINotifier(this._service, this._ref) : super(const VoiceAISessionState());

  /// Start a new voice session
  Future<void> startSession({Map<String, List<String>>? inventory}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final sessionInfo = await _service.startSession(
        inventory: inventory,
        onStateChange: (voiceState) {
          state = state.copyWith(
            voiceState: voiceState,
            isLoading: voiceState == VoiceAIState.connecting,
          );
        },
        onTranscript: (role, text) {
          final newTranscript = VoiceTranscript(
            role: role,
            text: text,
            timestamp: DateTime.now(),
          );
          state = state.copyWith(
            transcripts: [...state.transcripts, newTranscript],
          );
        },
        onQuotaUpdate: (quota) {
          state = state.copyWith(quota: quota);
        },
      );

      state = state.copyWith(
        isLoading: false,
        sessionInfo: sessionInfo,
        quota: sessionInfo.quota,
        voiceState: VoiceAIState.listening,
      );
    } on VoiceAITierRequiredException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message,
        voiceState: VoiceAIState.tierRequired,
        requiresUpgrade: true,
      );
    } on VoiceAIQuotaExceededException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message,
        voiceState: VoiceAIState.quotaExhausted,
        quota: e.quota,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        voiceState: VoiceAIState.error,
      );
    }
  }

  /// End the current session
  Future<void> endSession() async {
    await _service.endSession();

    // Refresh quota after session ends
    _ref.invalidate(voiceQuotaProvider);

    state = state.copyWith(
      voiceState: VoiceAIState.idle,
      sessionInfo: null,
      // Keep transcripts for review if needed
    );
  }

  /// Clear transcripts and reset state
  void reset() {
    state = const VoiceAISessionState();
  }

  /// Get current session duration
  int get sessionDuration => _service.sessionDuration;
}

/// State class for voice AI session
class VoiceAISessionState {
  final VoiceAIState voiceState;
  final bool isLoading;
  final String? error;
  final VoiceSessionInfo? sessionInfo;
  final VoiceQuota? quota;
  final List<VoiceTranscript> transcripts;
  final bool requiresUpgrade;

  const VoiceAISessionState({
    this.voiceState = VoiceAIState.idle,
    this.isLoading = false,
    this.error,
    this.sessionInfo,
    this.quota,
    this.transcripts = const [],
    this.requiresUpgrade = false,
  });

  VoiceAISessionState copyWith({
    VoiceAIState? voiceState,
    bool? isLoading,
    String? error,
    VoiceSessionInfo? sessionInfo,
    VoiceQuota? quota,
    List<VoiceTranscript>? transcripts,
    bool? requiresUpgrade,
  }) {
    return VoiceAISessionState(
      voiceState: voiceState ?? this.voiceState,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      sessionInfo: sessionInfo ?? this.sessionInfo,
      quota: quota ?? this.quota,
      transcripts: transcripts ?? this.transcripts,
      requiresUpgrade: requiresUpgrade ?? this.requiresUpgrade,
    );
  }

  bool get isConnected => voiceState != VoiceAIState.idle &&
                          voiceState != VoiceAIState.error &&
                          voiceState != VoiceAIState.tierRequired &&
                          voiceState != VoiceAIState.quotaExhausted;

  bool get canStartSession => voiceState == VoiceAIState.idle && !isLoading;
}

/// Provider for voice AI session state
final voiceAINotifierProvider = StateNotifierProvider<VoiceAINotifier, VoiceAISessionState>((ref) {
  final service = ref.watch(voiceAIServiceProvider);
  return VoiceAINotifier(service, ref);
});
