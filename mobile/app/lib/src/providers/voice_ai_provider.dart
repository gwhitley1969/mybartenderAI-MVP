import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/voice_ai_service.dart';
import 'backend_provider.dart';
import 'auth_provider.dart';

/// Provider for Voice AI service
final voiceAIServiceProvider = Provider<VoiceAIService>((ref) {
  final backendService = ref.watch(backendServiceProvider);
  final authService = ref.watch(authServiceProvider);
  return VoiceAIService(
    backendService.dio,
    getUserId: () async {
      // Get current user ID from auth state
      final user = ref.read(currentUserProvider);
      return user?.id;
    },
    getAccessToken: () async {
      // Get valid ID token for APIM JWT validation
      // NOTE: We use the ID token (not access token) because:
      // - ID token has audience = client app ID (f9f7f159-b847-4211-98c9-18e5b8193045)
      // - Access token has audience = Microsoft Graph (not valid for our APIM)
      // - APIM validates JWT audience against our client app ID
      return await authService.getValidIdToken();
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
        onTranscript: (role, text, isFinal) {
          _handleTranscript(role, text, isFinal);
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

  /// Handle incoming transcript updates
  /// For partial updates (isFinal=false): Update the last assistant message in-place
  /// For final updates (isFinal=true): Finalize the message
  void _handleTranscript(String role, String text, bool isFinal) {
    final transcripts = List<VoiceTranscript>.from(state.transcripts);

    if (role == 'assistant') {
      // Check if the last message is a partial assistant message
      final lastIndex = transcripts.length - 1;
      final hasPartialAssistant = transcripts.isNotEmpty &&
          transcripts.last.role == 'assistant' &&
          !transcripts.last.isFinal;

      if (hasPartialAssistant) {
        // Update the existing partial message
        transcripts[lastIndex] = transcripts.last.copyWith(
          text: text,
          isFinal: isFinal,
        );
      } else {
        // Create a new transcript entry
        transcripts.add(VoiceTranscript(
          role: role,
          text: text,
          timestamp: DateTime.now(),
          isFinal: isFinal,
        ));
      }
    } else {
      // User transcripts are always final, just add them
      transcripts.add(VoiceTranscript(
        role: role,
        text: text,
        timestamp: DateTime.now(),
        isFinal: true,
      ));
    }

    state = state.copyWith(transcripts: transcripts);
  }

  /// Clear transcripts and reset state
  void reset() {
    state = const VoiceAISessionState();
  }

  /// Set microphone muted state for push-to-talk
  /// Called when user presses (muted=false) or releases (muted=true) the button
  void setMicrophoneMuted(bool muted) {
    _service.setMicrophoneMuted(muted);
    state = state.copyWith(isMicMuted: muted);
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
  final bool isMicMuted; // Push-to-talk: true = not listening

  const VoiceAISessionState({
    this.voiceState = VoiceAIState.idle,
    this.isLoading = false,
    this.error,
    this.sessionInfo,
    this.quota,
    this.transcripts = const [],
    this.requiresUpgrade = false,
    this.isMicMuted = true, // Start muted for push-to-talk
  });

  VoiceAISessionState copyWith({
    VoiceAIState? voiceState,
    bool? isLoading,
    String? error,
    VoiceSessionInfo? sessionInfo,
    VoiceQuota? quota,
    List<VoiceTranscript>? transcripts,
    bool? requiresUpgrade,
    bool? isMicMuted,
  }) {
    return VoiceAISessionState(
      voiceState: voiceState ?? this.voiceState,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      sessionInfo: sessionInfo ?? this.sessionInfo,
      quota: quota ?? this.quota,
      transcripts: transcripts ?? this.transcripts,
      requiresUpgrade: requiresUpgrade ?? this.requiresUpgrade,
      isMicMuted: isMicMuted ?? this.isMicMuted,
    );
  }

  bool get isConnected => voiceState != VoiceAIState.idle &&
                          voiceState != VoiceAIState.error &&
                          voiceState != VoiceAIState.tierRequired &&
                          voiceState != VoiceAIState.quotaExhausted;

  bool get canStartSession => voiceState == VoiceAIState.idle && !isLoading;

  /// Returns true if in an active session and ready for push-to-talk interaction
  bool get canTalk => isConnected &&
                      (voiceState == VoiceAIState.listening ||
                       voiceState == VoiceAIState.speaking ||
                       voiceState == VoiceAIState.processing);
}

/// Provider for voice AI session state
final voiceAINotifierProvider = StateNotifierProvider<VoiceAINotifier, VoiceAISessionState>((ref) {
  final service = ref.watch(voiceAIServiceProvider);
  return VoiceAINotifier(service, ref);
});
