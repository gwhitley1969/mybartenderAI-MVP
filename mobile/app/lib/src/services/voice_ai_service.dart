import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_webrtc/src/native/ios/audio_configuration.dart';
import 'package:permission_handler/permission_handler.dart';

/// Voice AI Service for managing real-time voice conversations
/// with Azure OpenAI Realtime API via WebRTC
///
/// Production Architecture:
/// - Session setup (REST): Mobile App → Front Door → APIM (JWT validation) → Function App
/// - Voice conversation (WebRTC): Mobile App ←══ WebRTC ══→ Azure OpenAI Realtime API (direct)
///
/// APIM handles:
/// - JWT validation (Entra External ID)
/// - User ID extraction from JWT sub claim
/// - Rate limiting (10 requests/minute per user)
/// - Security headers
class VoiceAIService {
  // Production: Use APIM for secure access with JWT authentication
  // APIM extracts user ID from JWT and passes it to the function via X-User-Id header
  static const bool _bypassApim = false; // APIM is now configured for voice endpoints

  final Dio _dio;
  final Future<String?> Function() _getUserId; // Function to get current user ID
  final Future<String?> Function() _getAccessToken; // Function to get JWT access token
  late final Dio _voiceDio; // Uses shared APIM-configured Dio instance

  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  MediaStream? _localStream;

  // Session state
  String? _dbSessionId;
  String? _realtimeSessionId;
  DateTime? _sessionStartTime;
  int _durationSeconds = 0;

  // Active speech time tracking (metered time = user + AI speaking only)
  // This is FAIRER to users: pauses, network delays, and idle time are FREE!
  int _userSpeakingSeconds = 0;
  int _aiSpeakingSeconds = 0;
  DateTime? _userSpeechStartTime;
  // Note: _speakingStartTime (defined below) tracks AI speech start

  // Push-to-talk state - microphone starts muted
  bool _isMuted = true;

  // Transcripts collected during the session
  final List<VoiceTranscript> _transcripts = [];

  // Callbacks
  Function(VoiceAIState)? _onStateChange;
  Function(String, String, bool)? _onTranscript; // (role, text, isFinal)
  Function(VoiceQuota)? _onQuotaUpdate;

  // Buffer for accumulating streaming assistant response
  StringBuffer _currentAssistantResponse = StringBuffer();

  // Pending instructions to send via session.update after connection
  String? _pendingInstructions;

  VoiceAIState _state = VoiceAIState.idle;
  VoiceAIState get state => _state;

  // Background noise protection - tracks when AI started speaking
  // to implement a "speaking protection window" against false speech detections
  DateTime? _speakingStartTime;
  static const _minSpeakingDuration = Duration(milliseconds: 1500);  // Minimum time before allowing interruption
  bool _ignoringBackgroundNoise = false;  // Flag when we're actively filtering TV/background noise

  // Safety timeout: catches edge cases where processing state gets stuck
  // (network issues, Azure hiccups, race conditions)
  Timer? _processingTimeout;
  static const _maxProcessingDuration = Duration(seconds: 15);

  VoiceAIService(
    this._dio, {
    required Future<String?> Function() getUserId,
    required Future<String?> Function() getAccessToken,
  })  : _getUserId = getUserId,
        _getAccessToken = getAccessToken {
    // CRITICAL: Create a SEPARATE Dio instance for Voice AI requests
    //
    // Why? The shared _dio from BackendService has an interceptor that automatically
    // sets Authorization header with the Graph access token (for Microsoft Graph API).
    // But Voice AI endpoints require the ID token (with aud=client_app_id) for APIM
    // JWT validation. The interceptor would OVERWRITE our correct ID token with the
    // wrong Graph token, causing 401 errors.
    //
    // By creating a fresh Dio instance without interceptors, we ensure the
    // Authorization header we set in _getAuthHeaders() is preserved.
    _voiceDio = Dio(BaseOptions(
      baseUrl: _dio.options.baseUrl,
      connectTimeout: _dio.options.connectTimeout,
      receiveTimeout: _dio.options.receiveTimeout,
    ));

    // Add logging interceptor for debugging (this one doesn't modify headers)
    _voiceDio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));

    debugPrint('VoiceAIService: Initialized with dedicated Dio instance (no auth interceptor)');
    debugPrint('VoiceAIService: Base URL: ${_voiceDio.options.baseUrl}');
  }

  /// Get headers for voice API calls
  /// Explicitly adds Authorization header with JWT token for APIM JWT validation
  /// APIM extracts user ID from JWT sub claim and sets X-User-Id header for backend
  Future<Map<String, String>> _getAuthHeaders() async {
    final headers = <String, String>{};

    debugPrint('=== VoiceAIService: _getAuthHeaders START ===');

    // Get JWT access token for APIM authentication
    try {
      debugPrint('VoiceAIService: Calling _getAccessToken()...');
      final accessToken = await _getAccessToken();
      debugPrint('VoiceAIService: _getAccessToken returned: ${accessToken == null ? "NULL" : "${accessToken.length} chars"}');

      if (accessToken != null && accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $accessToken';
        // Log token preview for debugging (first 20 chars only)
        final preview = accessToken.length > 20 ? '${accessToken.substring(0, 20)}...' : accessToken;
        debugPrint('VoiceAIService: Added Authorization header, token starts with: $preview');
      } else {
        debugPrint('VoiceAIService: ERROR - No access token available!');
        debugPrint('VoiceAIService: accessToken is ${accessToken == null ? "null" : "empty string"}');
      }
    } catch (e, stackTrace) {
      debugPrint('VoiceAIService: EXCEPTION getting access token: $e');
      debugPrint('VoiceAIService: Stack trace: $stackTrace');
    }

    debugPrint('VoiceAIService: Final headers keys: ${headers.keys.toList()}');
    debugPrint('=== VoiceAIService: _getAuthHeaders END ===');
    return headers;
  }

  /// Request microphone permission
  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Check if microphone permission is granted
  Future<bool> hasMicrophonePermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// Get current mute state for push-to-talk
  bool get isMuted => _isMuted;

  /// Set microphone mute state for push-to-talk
  /// When unmuting (button pressed), prepares audio pipeline for a new utterance
  /// When muting (button released), commits the audio buffer so AI responds immediately
  void setMicrophoneMuted(bool muted) {
    _isMuted = muted;

    // When UNMUTING (user pressed button), prepare for new utterance
    // This clears residual audio (echo) and cancels any in-progress AI response
    if (!muted) {
      _prepareForNewUtterance();
    }

    // When MUTING (user released button), finalize any in-progress speech tracking.
    // Needed because speech_stopped events are now ignored while muted,
    // but the event may arrive after the mic is already muted.
    if (muted && _userSpeechStartTime != null) {
      final speechDuration = DateTime.now().difference(_userSpeechStartTime!).inSeconds;
      _userSpeakingSeconds += speechDuration;
      debugPrint('[VOICE-AI] User speech finalized on mute: +${speechDuration}s (total: ${_userSpeakingSeconds}s)');
      _userSpeechStartTime = null;
    }

    // Mute/unmute the local audio track
    if (_localStream != null) {
      final audioTracks = _localStream!.getAudioTracks();
      for (final track in audioTracks) {
        track.enabled = !muted;
      }
    }

    debugPrint('[VOICE-AI] Microphone ${muted ? "MUTED" : "UNMUTED"} (push-to-talk)');

    // When muting (user released button), commit the audio buffer
    // This tells Azure to process the audio immediately without waiting for VAD
    if (muted && _dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen) {
      _commitAudioBuffer();
    }
  }

  /// Prepare the audio pipeline for a new user utterance.
  /// Implements the official Azure OpenAI WebRTC push-to-talk procedure:
  /// 1. Clear input buffer (removes echo/residual audio from previous AI playback)
  /// 2. Cancel any in-progress response (if AI is still speaking/processing)
  /// 3. Clear output audio buffer (stops AI playback immediately, WebRTC-specific)
  void _prepareForNewUtterance() {
    if (_dataChannel?.state != RTCDataChannelState.RTCDataChannelOpen) return;

    // Step 1: Always clear the input buffer to remove echo/residual audio
    _dataChannel!.send(RTCDataChannelMessage(jsonEncode({
      'type': 'input_audio_buffer.clear',
    })));
    debugPrint('[VOICE-AI] Input buffer cleared for new utterance');

    // Step 2 & 3: If AI is speaking/processing, cancel response and clear output
    if (_state == VoiceAIState.speaking || _state == VoiceAIState.processing) {
      _dataChannel!.send(RTCDataChannelMessage(jsonEncode({
        'type': 'response.cancel',
      })));
      debugPrint('[VOICE-AI] Cancelled in-progress response');

      _dataChannel!.send(RTCDataChannelMessage(jsonEncode({
        'type': 'output_audio_buffer.clear',
      })));
      debugPrint('[VOICE-AI] Cleared output audio buffer (stopped AI playback)');

      // Force state to listening since we just cancelled the AI
      _speakingStartTime = null;
      _ignoringBackgroundNoise = false;
      _setState(VoiceAIState.listening);
    }
  }

  /// Commit the audio buffer and request immediate AI response
  /// Called when user releases the push-to-talk button
  void _commitAudioBuffer() {
    if (_dataChannel?.state != RTCDataChannelState.RTCDataChannelOpen) {
      debugPrint('[VOICE-AI] Cannot commit - data channel not open');
      return;
    }

    // Step 1: Commit the audio buffer (tells Azure we're done sending audio)
    final commitEvent = jsonEncode({
      'type': 'input_audio_buffer.commit',
    });
    _dataChannel!.send(RTCDataChannelMessage(commitEvent));
    debugPrint('[VOICE-AI] Audio buffer committed');

    // Step 2: Explicitly request a response (don't wait for VAD processing)
    // This triggers immediate response generation without semantic VAD delay
    final responseEvent = jsonEncode({
      'type': 'response.create',
    });
    _dataChannel!.send(RTCDataChannelMessage(responseEvent));
    debugPrint('[VOICE-AI] Response requested - AI will respond immediately');

    // Update state to processing
    _setState(VoiceAIState.processing);
  }

  /// Get current voice quota for the user
  Future<VoiceQuota> getVoiceQuota() async {
    try {
      debugPrint('VoiceAIService: Getting voice quota...');
      final headers = await _getAuthHeaders();
      final response = await _voiceDio.get(
        '/v1/voice/quota',
        options: Options(headers: headers),
      );
      debugPrint('VoiceAIService: Got quota response: ${response.data}');
      return VoiceQuota.fromJson(response.data);
    } catch (e) {
      debugPrint('VoiceAIService: Failed to get quota: $e');
      throw VoiceAIException('Failed to get voice quota: $e');
    }
  }

  /// Start a new voice session
  /// Returns the session info if successful
  Future<VoiceSessionInfo> startSession({
    Map<String, List<String>>? inventory,
    required Function(VoiceAIState) onStateChange,
    required Function(String, String, bool) onTranscript, // (role, text, isFinal)
    Function(VoiceQuota)? onQuotaUpdate,
  }) async {
    _onStateChange = onStateChange;
    _onTranscript = onTranscript;
    _onQuotaUpdate = onQuotaUpdate;

    // Build inventory instructions to send via session.update after connection
    if (inventory != null && (inventory['spirits']?.isNotEmpty ?? false)) {
      _pendingInstructions = _buildInventoryInstructions(inventory);
      debugPrint('[VOICE-AI] Built inventory instructions for ${inventory['spirits']?.length ?? 0} ingredients');
    } else {
      _pendingInstructions = null;
      debugPrint('[VOICE-AI] No inventory provided for session');
    }

    _setState(VoiceAIState.connecting);

    try {
      // Check microphone permission
      if (!await hasMicrophonePermission()) {
        final granted = await requestMicrophonePermission();
        if (!granted) {
          _setState(VoiceAIState.error);
          throw VoiceAIException('Microphone permission denied');
        }
      }

      // Request session and ephemeral token from backend
      debugPrint('=== VoiceAIService: Starting voice session request ===');
      debugPrint('VoiceAIService: Base URL: ${_voiceDio.options.baseUrl}');

      final headers = await _getAuthHeaders();
      debugPrint('VoiceAIService: Headers to send: ${headers.keys.toList()}');
      debugPrint('VoiceAIService: Has Authorization: ${headers.containsKey("Authorization")}');

      final requestUrl = '/v1/voice/session';
      debugPrint('VoiceAIService: Making POST to: $requestUrl');

      final response = await _voiceDio.post(
        requestUrl,
        data: {
          if (inventory != null) 'inventory': inventory,
        },
        options: Options(headers: headers),
      );

      debugPrint('VoiceAIService: Response status: ${response.statusCode}');
      debugPrint('VoiceAIService: Response data: ${response.data}');

      if (response.data['success'] != true) {
        _setState(VoiceAIState.error);
        final error = response.data['error'] ?? 'unknown_error';
        if (error == 'tier_required') {
          _setState(VoiceAIState.tierRequired);
          throw VoiceAITierRequiredException(
            response.data['message'] ?? 'Pro tier required',
            response.data['requiredTier'] ?? 'pro',
            response.data['currentTier'] ?? 'free',
          );
        } else if (error == 'quota_exceeded') {
          _setState(VoiceAIState.quotaExhausted);
          throw VoiceAIQuotaExceededException(
            response.data['message'] ?? 'Voice quota exceeded',
            VoiceQuota.fromQuotaData(response.data['quota']),
          );
        }
        throw VoiceAIException(response.data['message'] ?? 'Failed to start session');
      }

      final sessionData = response.data;
      _dbSessionId = sessionData['session']['dbSessionId']?.toString();
      _realtimeSessionId = sessionData['session']['realtimeSessionId'];
      _sessionStartTime = DateTime.now();
      _transcripts.clear();
      _currentAssistantResponse = StringBuffer(); // Clear any pending partial response

      // Reset active speech time tracking for new session
      _userSpeakingSeconds = 0;
      _aiSpeakingSeconds = 0;
      _userSpeechStartTime = null;

      final token = sessionData['token']['value'];
      final webrtcUrl = sessionData['webrtcUrl'];

      // Update quota info
      if (_onQuotaUpdate != null && sessionData['quota'] != null) {
        _onQuotaUpdate!(VoiceQuota.fromQuotaData(sessionData['quota']));
      }

      // Establish WebRTC connection
      await _connectWebRTC(token, webrtcUrl);

      _setState(VoiceAIState.listening);

      return VoiceSessionInfo(
        dbSessionId: _dbSessionId!,
        realtimeSessionId: _realtimeSessionId!,
        model: sessionData['session']['model'],
        voice: sessionData['session']['voice'],
        quota: VoiceQuota.fromQuotaData(sessionData['quota']),
      );
    } on DioException catch (e) {
      // Handle HTTP error responses with proper user-friendly messages
      debugPrint('=== VoiceAIService: DioException caught ===');
      debugPrint('VoiceAIService: Error type: ${e.type}');
      debugPrint('VoiceAIService: Error message: ${e.message}');
      debugPrint('VoiceAIService: Request URL: ${e.requestOptions.uri}');
      debugPrint('VoiceAIService: Request headers: ${e.requestOptions.headers}');

      if (e.response != null) {
        final statusCode = e.response!.statusCode;
        final data = e.response!.data;
        final responseHeaders = e.response!.headers;

        debugPrint('VoiceAIService: Response status: $statusCode');
        debugPrint('VoiceAIService: Response headers: ${responseHeaders.map}');
        debugPrint('VoiceAIService: Response data: $data');

        if (data is Map<String, dynamic>) {
          final error = data['error'] ?? 'unknown_error';
          final message = data['message'] ?? 'An error occurred';

          if (statusCode == 403) {
            if (error == 'tier_required') {
              _setState(VoiceAIState.tierRequired);
              throw VoiceAITierRequiredException(
                message,
                data['requiredTier'] ?? 'pro',
                data['currentTier'] ?? 'free',
              );
            } else if (error == 'quota_exceeded') {
              _setState(VoiceAIState.quotaExhausted);
              throw VoiceAIQuotaExceededException(
                message,
                VoiceQuota.fromQuotaData(data['quota'] ?? {}),
              );
            }
          }

          // Other API errors with messages
          _setState(VoiceAIState.error);
          throw VoiceAIException(message);
        }
      }

      // Network or unknown Dio errors
      _setState(VoiceAIState.error);
      if (e.type == DioExceptionType.connectionTimeout) {
        throw VoiceAIException('Connection timed out. Please check your internet connection.');
      } else if (e.type == DioExceptionType.connectionError) {
        throw VoiceAIException('Unable to connect. Please check your internet connection.');
      }
      throw VoiceAIException('Network error. Please try again.');
    } catch (e) {
      if (e is VoiceAIException) rethrow;
      _setState(VoiceAIState.error);
      throw VoiceAIException('Failed to start voice session. Please try again.');
    }
  }

  /// Connect to WebRTC endpoint with ephemeral token
  Future<void> _connectWebRTC(String token, String webrtcUrl) async {
    try {
      // Get local audio stream with enhanced noise filtering
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
          // Enhanced noise filtering for noisy environments (TV, conversations)
          'googNoiseSuppression': true,    // Chrome-specific enhanced suppression
          'googHighpassFilter': true,       // Filter low-frequency background noise
          'channelCount': 1,                // Mono audio (reduces complexity)
        },
        'video': false,
      });

      // Create peer connection
      _peerConnection = await createPeerConnection({
        'iceServers': [], // Azure handles ICE
        'sdpSemantics': 'unified-plan',
      });

      // Add local audio track
      final audioTrack = _localStream!.getAudioTracks().first;
      await _peerConnection!.addTrack(audioTrack, _localStream!);

      // Push-to-talk: Start with microphone muted
      // User must press and hold the button to speak
      _isMuted = true;
      audioTrack.enabled = false;
      debugPrint('[VOICE-AI] Push-to-talk: Microphone starts MUTED');

      // Handle incoming audio track from AI (for logging only)
      // NOTE: onTrack fires when the track is ADDED to the connection during setup,
      // NOT when the AI actually starts speaking. Do NOT change state here!
      // The correct event for AI speaking is 'output_audio_buffer.started' from data channel.
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (event.track.kind == 'audio') {
          debugPrint('[VOICE-AI] Remote audio track received (AI can now send audio)');
          // State will transition to 'speaking' when output_audio_buffer.started is received
        }
      };

      // Create data channel for events/transcripts
      _dataChannel = await _peerConnection!.createDataChannel(
        'oai-events',
        RTCDataChannelInit(),
      );

      _dataChannel!.onMessage = (RTCDataChannelMessage message) {
        _handleDataChannelMessage(message.text);
      };

      // Send inventory instructions when data channel opens
      _dataChannel!.onDataChannelState = (RTCDataChannelState state) {
        debugPrint('[VOICE-AI] Data channel state changed: $state');
        if (state == RTCDataChannelState.RTCDataChannelOpen) {
          debugPrint('[VOICE-AI] Data channel opened');
          _sendSessionUpdate();
        }
      };

      // Create offer
      final offer = await _peerConnection!.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': false,
      });
      await _peerConnection!.setLocalDescription(offer);

      // Send offer to Azure OpenAI Realtime API
      final sdpResponse = await Dio().post(
        webrtcUrl,
        data: offer.sdp,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/sdp',
          },
        ),
      );

      // Set remote description
      final answer = RTCSessionDescription(sdpResponse.data, 'answer');
      await _peerConnection!.setRemoteDescription(answer);

      // Monitor connection state
      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        switch (state) {
          case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
            _setState(VoiceAIState.listening);
            break;
          case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
          case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
            _setState(VoiceAIState.error);
            break;
          default:
            break;
        }
      };

      // iOS-specific: Force speaker output AFTER peer connection is established
      // This must happen AFTER WebRTC setup to override iOS's default earpiece routing
      // Calling before peer connection doesn't work because WebRTC overrides the settings
      if (Platform.isIOS) {
        // Configure audio session with explicit defaultToSpeaker option
        await Helper.setAppleAudioConfiguration(AppleAudioConfiguration(
          appleAudioCategory: AppleAudioCategory.playAndRecord,
          appleAudioCategoryOptions: {
            AppleAudioCategoryOption.defaultToSpeaker, // KEY: Forces speaker!
            AppleAudioCategoryOption.allowBluetooth,
            AppleAudioCategoryOption.allowBluetoothA2DP,
            AppleAudioCategoryOption.allowAirPlay,
          },
          appleAudioMode: AppleAudioMode.voiceChat,
        ));

        // Also call setSpeakerphoneOn for belt-and-suspenders approach
        await Helper.setSpeakerphoneOn(true);

        debugPrint('[VOICE-AI] iOS audio configured for speaker output');
      }
    } catch (e) {
      await _cleanup();
      throw VoiceAIException('WebRTC connection failed: $e');
    }
  }

  /// Handle incoming data channel messages (transcripts, state changes)
  void _handleDataChannelMessage(String message) {
    try {
      final data = json.decode(message);
      final type = data['type'];

      // Debug logging for all events - helps diagnose background noise issues
      debugPrint('[VOICE-AI] EVENT: $type | State: $_state | Time: ${DateTime.now().toIso8601String()}');

      // Verbose logging for diagnostic events (helps debug background noise issues)
      if (type == 'input_audio_buffer.speech_started' ||
          type == 'input_audio_buffer.speech_stopped' ||
          type == 'conversation.interrupted' ||
          type == 'response.done' ||
          type == 'response.audio.done' ||
          type == 'response.audio.started') {
        debugPrint('[VOICE-AI] FULL EVENT DATA: ${json.encode(data)}');
      }

      switch (type) {
        case 'response.audio_transcript.delta':
          // AI response transcript - streaming word-by-word
          // Accumulate the delta into the current response buffer
          final delta = data['delta'] ?? '';
          if (delta.isNotEmpty) {
            _currentAssistantResponse.write(delta);
            // Emit partial update (isFinal=false) with accumulated text so far
            _onTranscript?.call('assistant', _currentAssistantResponse.toString(), false);
          }
          break;

        case 'response.audio_transcript.done':
          // AI response complete - finalize the transcript
          final finalTranscript = data['transcript'] ?? _currentAssistantResponse.toString();
          if (finalTranscript.isNotEmpty) {
            // Add to permanent transcripts list
            _transcripts.add(VoiceTranscript(
              role: 'assistant',
              text: finalTranscript,
              timestamp: DateTime.now(),
            ));
            // Emit final update (isFinal=true)
            _onTranscript?.call('assistant', finalTranscript, true);
          }
          // Clear the buffer for the next response
          _currentAssistantResponse = StringBuffer();
          break;

        case 'conversation.item.input_audio_transcription.completed':
          // User speech transcript - always comes as complete
          final transcript = data['transcript'] ?? '';
          if (transcript.isNotEmpty) {
            _transcripts.add(VoiceTranscript(
              role: 'user',
              text: transcript,
              timestamp: DateTime.now(),
            ));
            // User transcripts are always final
            _onTranscript?.call('user', transcript, true);
          }
          break;

        case 'input_audio_buffer.speech_started':
          // FIRST CHECK: If mic is muted, ALL speech detections are background noise.
          // In push-to-talk mode, the button press handles state transitions,
          // so VAD events while muted are never meaningful.
          if (_isMuted) {
            debugPrint('[VOICE-AI] IGNORED speech_started - mic is MUTED (background noise)');
            _ignoringBackgroundNoise = true;
            break;
          }

          // Mic is unmuted — user is holding the push-to-talk button
          if (_state != VoiceAIState.speaking) {
            _userSpeechStartTime = DateTime.now();
            _setState(VoiceAIState.listening);
          } else {
            // User pressed button while AI is speaking — already cancelled in _prepareForNewUtterance()
            debugPrint('[VOICE-AI] User speaking during interrupted AI (push-to-talk active)');
            _userSpeechStartTime = DateTime.now();
            _setState(VoiceAIState.listening);
          }
          break;

        case 'input_audio_buffer.speech_stopped':
          // FIRST CHECK: If mic is muted, ignore — this is background noise ending.
          // Do NOT transition to processing, or the state will get stuck forever
          // (because create_response: false means no auto-response from VAD).
          if (_isMuted) {
            debugPrint('[VOICE-AI] IGNORED speech_stopped - mic is MUTED (background noise ended)');
            _ignoringBackgroundNoise = false;
            break;
          }

          // Mic is unmuted — only transition if we were actually listening
          if (_state == VoiceAIState.listening) {
            if (_userSpeechStartTime != null) {
              final speechDuration = DateTime.now().difference(_userSpeechStartTime!).inSeconds;
              _userSpeakingSeconds += speechDuration;
              debugPrint('[VOICE-AI] User speech: +${speechDuration}s (total: ${_userSpeakingSeconds}s)');
              _userSpeechStartTime = null;
            }
            _setState(VoiceAIState.processing);
          } else {
            debugPrint('[VOICE-AI] IGNORED speech_stopped - was not in listening state (state: $_state)');
          }
          break;

        // CRITICAL: Use output_audio_buffer.started (NOT response.audio.started which doesn't exist!)
        // This event fires when audio PLAYBACK actually begins on the client
        case 'output_audio_buffer.started':
          _speakingStartTime = DateTime.now();
          _ignoringBackgroundNoise = false;  // Reset on new response
          debugPrint('[VOICE-AI] AI started speaking (audio playback began) at $_speakingStartTime');
          _setState(VoiceAIState.speaking);
          break;

        // CRITICAL: Use output_audio_buffer.stopped for state transitions (NOT response.audio.done!)
        // This event fires when audio PLAYBACK actually stops (natural end or interruption)
        case 'output_audio_buffer.stopped':
          if (_state == VoiceAIState.speaking) {
            final speakingDuration = _speakingStartTime != null
                ? DateTime.now().difference(_speakingStartTime!)
                : Duration.zero;
            debugPrint('[VOICE-AI] AI stopped speaking (audio playback ended) - duration: ${speakingDuration.inMilliseconds}ms');

            // Accumulate AI speech time for active metering
            if (_speakingStartTime != null) {
              final aiSpeechSeconds = speakingDuration.inSeconds;
              _aiSpeakingSeconds += aiSpeechSeconds;
              debugPrint('[VOICE-AI] AI speech: +${aiSpeechSeconds}s (total: ${_aiSpeakingSeconds}s)');
            }

            // Check if this might be a premature end due to background noise
            if (_ignoringBackgroundNoise && speakingDuration < _minSpeakingDuration) {
              debugPrint('[VOICE-AI] WARNING: Playback stopped quickly (${speakingDuration.inMilliseconds}ms) while ignoring background noise');
              debugPrint('[VOICE-AI] This may indicate Azure truncated the response despite interrupt_response:false');
            }

            _speakingStartTime = null;
            _ignoringBackgroundNoise = false;
            _setState(VoiceAIState.listening);
          } else {
            debugPrint('[VOICE-AI] output_audio_buffer.stopped received but not in speaking state (state: $_state)');
          }
          break;

        // response.audio.done and response.done indicate GENERATION complete, NOT playback complete
        // Do NOT change state here - let output_audio_buffer.stopped handle state transitions
        case 'response.audio.done':
        case 'response.done':
          debugPrint('[VOICE-AI] Response generation complete (state: $_state, playback may still be ongoing)');
          // Note: We intentionally do NOT transition state here.
          // The output_audio_buffer.stopped event handles the actual end of playback.
          break;

        case 'session.updated':
          // Confirmation that session.update was applied (instructions set)
          debugPrint('[VOICE-AI] Session updated - inventory instructions applied successfully');
          break;

        case 'conversation.interrupted':
          // Azure detected an interruption - this may be from background noise (TV dialogue)
          // With interrupt_response:false configured, Azure SHOULD NOT truncate the response,
          // but we've seen it still send this event.
          final interruptedDuration = _speakingStartTime != null
              ? DateTime.now().difference(_speakingStartTime!)
              : Duration.zero;

          debugPrint('[VOICE-AI] INTERRUPTED event received after ${interruptedDuration.inMilliseconds}ms speaking');
          debugPrint('[VOICE-AI] This may be false detection from TV/background noise - NOT changing state');

          // Set flag to track if we're being interrupted during a response
          if (_state == VoiceAIState.speaking) {
            _ignoringBackgroundNoise = true;
            // IMPORTANT: Do NOT send any commands to Azure here!
            // Sending input_audio_buffer.clear or other commands during response generation
            // can cause Azure to abort with a server error. Just ignore client-side.
          }
          break;

        case 'error':
          // Error message available in data['error']?['message']
          debugPrint('VoiceAIService: Received error from data channel: ${data['error']}');
          _setState(VoiceAIState.error);
          break;

        case 'response.cancelled':
          debugPrint('[VOICE-AI] Response cancelled successfully (user interrupted via push-to-talk)');
          break;

        case 'input_audio_buffer.cleared':
          debugPrint('[VOICE-AI] Input audio buffer cleared (echo/residual audio removed)');
          break;

        case 'output_audio_buffer.cleared':
          debugPrint('[VOICE-AI] Output audio buffer cleared (AI playback stopped)');
          break;

        // Events we want to track but don't need to act on
        // NOTE: response.audio_transcript.delta and response.audio_transcript.done
        // are handled above for transcript processing - do NOT duplicate here!
        case 'response.created':
        case 'response.output_item.added':
        case 'response.output_item.done':
        case 'response.content_part.added':
        case 'response.content_part.done':
        case 'input_audio_buffer.committed':
        case 'conversation.item.created':
        case 'conversation.item.truncated':
        case 'rate_limits.updated':
        case 'session.created':
          // These are informational events - already logged above
          break;

        default:
          // Log any unhandled events so we can see what we might be missing
          debugPrint('[VOICE-AI] UNHANDLED EVENT: $type | Data: ${json.encode(data)}');
          break;
      }
    } catch (e) {
      debugPrint('VoiceAIService: Error parsing data channel message: $e');
    }
  }

  /// End the voice session and record usage
  Future<void> endSession() async {
    if (_dbSessionId == null || _sessionStartTime == null) {
      await _cleanup();
      _setState(VoiceAIState.idle);
      return;
    }

    // If user was speaking when session ended, finalize their speech time
    if (_userSpeechStartTime != null) {
      final finalUserSpeech = DateTime.now().difference(_userSpeechStartTime!).inSeconds;
      _userSpeakingSeconds += finalUserSpeech;
      _userSpeechStartTime = null;
    }

    // If AI was speaking when session ended, finalize AI speech time
    if (_speakingStartTime != null) {
      final finalAiSpeech = DateTime.now().difference(_speakingStartTime!).inSeconds;
      _aiSpeakingSeconds += finalAiSpeech;
    }

    // Calculate ACTIVE speech duration (user + AI talking only)
    // This is FAIRER to users: pauses, network delays, and idle time are FREE!
    _durationSeconds = _userSpeakingSeconds + _aiSpeakingSeconds;
    final connectedTime = DateTime.now().difference(_sessionStartTime!).inSeconds;
    debugPrint('[VOICE-AI] Active speech metering: user=${_userSpeakingSeconds}s + AI=${_aiSpeakingSeconds}s = ${_durationSeconds}s (connected: ${connectedTime}s)');

    // Safety: If active speech metering shows 0 but session was substantial,
    // fall back to a fraction of wall-clock time as a conservative estimate.
    // This catches edge cases where VAD speech_started events never fired
    // (e.g., very short interactions, Azure latency, push-to-talk timing).
    if (_durationSeconds == 0 && connectedTime > 10) {
      _durationSeconds = (connectedTime * 0.3).round();
      debugPrint('[VOICE-AI] WARNING: Speech metering 0 for ${connectedTime}s session, fallback: ${_durationSeconds}s');
    }

    try {
      // Record usage on backend
      debugPrint('VoiceAIService: Recording voice usage...');
      final headers = await _getAuthHeaders();
      final response = await _voiceDio.post(
        '/v1/voice/usage',
        data: {
          'sessionId': _dbSessionId,
          'durationSeconds': _durationSeconds,
          'transcripts': _transcripts.map((t) => {
            'role': t.role,
            'transcript': t.text,
            'timestamp': t.timestamp.toIso8601String(),
          }).toList(),
        },
        options: Options(headers: headers),
      );
      debugPrint('VoiceAIService: Usage recorded: ${response.data}');

      // Update quota if returned
      if (_onQuotaUpdate != null && response.data['quota'] != null) {
        _onQuotaUpdate!(VoiceQuota.fromQuotaData(response.data['quota']));
      }
    } catch (e) {
      debugPrint('VoiceAIService: Failed to record voice usage: $e');
    }

    await _cleanup();
    _setState(VoiceAIState.idle);
  }

  /// Clean up WebRTC resources
  Future<void> _cleanup() async {
    try {
      // Cancel safety timeout
      _processingTimeout?.cancel();
      _processingTimeout = null;

      _dataChannel?.close();
      _dataChannel = null;

      await _peerConnection?.close();
      _peerConnection = null;

      _localStream?.getTracks().forEach((track) => track.stop());
      await _localStream?.dispose();
      _localStream = null;

      _dbSessionId = null;
      _realtimeSessionId = null;
      _sessionStartTime = null;
      _isMuted = true; // Reset to muted for next session

      // Reset active speech time tracking
      _userSpeakingSeconds = 0;
      _aiSpeakingSeconds = 0;
      _userSpeechStartTime = null;
    } catch (e) {
      debugPrint('VoiceAIService: Error during cleanup: $e');
    }
  }

  void _setState(VoiceAIState newState) {
    // Manage processing safety timeout
    if (newState == VoiceAIState.processing) {
      // Starting processing — arm the safety timeout
      _processingTimeout?.cancel();
      _processingTimeout = Timer(_maxProcessingDuration, () {
        if (_state == VoiceAIState.processing) {
          debugPrint('[VOICE-AI] SAFETY TIMEOUT: Processing stuck for ${_maxProcessingDuration.inSeconds}s — falling back to listening');
          _state = VoiceAIState.listening;
          _onStateChange?.call(VoiceAIState.listening);
        }
      });
    } else {
      // Leaving processing (or entering any other state) — cancel the timeout
      _processingTimeout?.cancel();
      _processingTimeout = null;
    }

    _state = newState;
    _onStateChange?.call(newState);
  }

  /// Get the current session duration in seconds
  int get sessionDuration {
    if (_sessionStartTime == null) return 0;
    return DateTime.now().difference(_sessionStartTime!).inSeconds;
  }

  /// Get collected transcripts
  List<VoiceTranscript> get transcripts => List.unmodifiable(_transcripts);

  /// Dispose service resources
  Future<void> dispose() async {
    await _cleanup();
  }

  /// Build inventory instructions string for session.update
  String _buildInventoryInstructions(Map<String, List<String>> inventory) {
    final allIngredients = inventory['spirits'] ?? [];
    final mixers = inventory['mixers'] ?? [];

    // Combine all ingredients
    final combined = [...allIngredients, ...mixers].where((s) => s.isNotEmpty).toList();

    return '''
USER'S BAR INVENTORY:
The user has these ingredients in their home bar: ${combined.join(', ')}

IMPORTANT: When the user asks what they can make or for drink suggestions, you MUST reference these specific ingredients. Suggest cocktails that can be made using ONLY these available ingredients. If they ask "what's in my bar" or "what do I have", list these ingredients.
''';
  }

  /// Send session.update event via data channel to apply VAD config and instructions
  void _sendSessionUpdate() {
    if (_dataChannel == null) {
      debugPrint('[VOICE-AI] Data channel is null, cannot send session.update');
      return;
    }

    if (_dataChannel!.state != RTCDataChannelState.RTCDataChannelOpen) {
      debugPrint('[VOICE-AI] Data channel not open (state: ${_dataChannel!.state}), cannot send session.update');
      return;
    }

    // Build session config with VAD settings and optional instructions
    final sessionConfig = <String, dynamic>{
      // Semantic VAD - uses AI to understand speech, not just volume
      // 'low' eagerness = more tolerant of background noise/pauses
      'turn_detection': {
        'type': 'semantic_vad',
        'eagerness': 'low',
        'create_response': false,     // Push-to-talk sends explicit response.create on button release
        'interrupt_response': false,
      },
      // Noise reduction filter for phone speaker/mic usage
      'input_audio_noise_reduction': {
        'type': 'far_field',
      },
    };

    // Add inventory instructions if available
    if (_pendingInstructions != null) {
      sessionConfig['instructions'] = _pendingInstructions;
      debugPrint('[VOICE-AI] Including inventory instructions');
    }

    final event = json.encode({
      'type': 'session.update',
      'session': sessionConfig,
    });

    debugPrint('[VOICE-AI] Sending session.update with VAD config (semantic_vad + far_field noise reduction)');
    if (_pendingInstructions != null) {
      debugPrint('[VOICE-AI] Instructions: $_pendingInstructions');
    }

    _dataChannel!.send(RTCDataChannelMessage(event));
    _pendingInstructions = null; // Clear after sending
    debugPrint('[VOICE-AI] session.update sent successfully');
  }

  /// Send a generic command via the data channel
  /// Used for commands like input_audio_buffer.clear to discard false speech detection
  void _sendDataChannelMessage(Map<String, dynamic> message) {
    if (_dataChannel == null) {
      debugPrint('[VOICE-AI] Data channel is null, cannot send message');
      return;
    }

    if (_dataChannel!.state != RTCDataChannelState.RTCDataChannelOpen) {
      debugPrint('[VOICE-AI] Data channel not open (state: ${_dataChannel!.state}), cannot send message');
      return;
    }

    final event = json.encode(message);
    debugPrint('[VOICE-AI] Sending command: ${message['type']}');
    _dataChannel!.send(RTCDataChannelMessage(event));
  }
}

/// Voice AI connection states
enum VoiceAIState {
  idle,           // Initial - show "Talk" button
  connecting,     // Fetching token, establishing WebRTC
  listening,      // User can speak (mic active)
  processing,     // VAD detected silence, waiting for AI
  speaking,       // AI audio playing
  error,          // Connection/API error
  quotaExhausted, // Minutes depleted
  tierRequired,   // User needs to upgrade to Pro
}

/// Voice quota information
class VoiceQuota {
  final bool hasAccess;
  final bool hasQuota;
  final String tier;
  final int remainingSeconds;
  final int remainingMinutes;
  final int monthlyUsedSeconds;
  final int monthlyLimitSeconds;
  final int addonSecondsRemaining;
  final int percentUsed;
  final bool showWarning;
  final String? warningMessage;

  VoiceQuota({
    required this.hasAccess,
    required this.hasQuota,
    required this.tier,
    required this.remainingSeconds,
    required this.remainingMinutes,
    required this.monthlyUsedSeconds,
    required this.monthlyLimitSeconds,
    required this.addonSecondsRemaining,
    required this.percentUsed,
    required this.showWarning,
    this.warningMessage,
  });

  factory VoiceQuota.fromJson(Map<String, dynamic> json) {
    final quota = json['quota'] ?? {};
    return VoiceQuota(
      hasAccess: json['hasAccess'] ?? false,
      hasQuota: json['hasQuota'] ?? false,
      tier: json['tier'] ?? 'free',
      remainingSeconds: quota['remainingSeconds'] ?? 0,
      remainingMinutes: quota['remainingMinutes'] ?? 0,
      monthlyUsedSeconds: quota['monthlyUsedSeconds'] ?? 0,
      monthlyLimitSeconds: quota['monthlyLimitSeconds'] ?? 3600,  // 60 min default
      addonSecondsRemaining: quota['addonSecondsRemaining'] ?? 0,
      percentUsed: quota['percentUsed'] ?? 0,
      showWarning: json['showWarning'] ?? false,
      warningMessage: json['warningMessage'],
    );
  }

  factory VoiceQuota.fromQuotaData(Map<String, dynamic> quota) {
    return VoiceQuota(
      hasAccess: true,
      hasQuota: (quota['remainingSeconds'] ?? 0) > 0,
      tier: 'pro',
      remainingSeconds: quota['remainingSeconds'] ?? 0,
      remainingMinutes: ((quota['remainingSeconds'] ?? 0) / 60).floor(),
      monthlyUsedSeconds: quota['monthlyUsedSeconds'] ?? 0,
      monthlyLimitSeconds: quota['monthlyLimitSeconds'] ?? 3600,  // 60 min default
      addonSecondsRemaining: quota['addonSecondsRemaining'] ?? 0,
      percentUsed: quota['monthlyLimitSeconds'] != null && quota['monthlyLimitSeconds'] > 0
          ? ((quota['monthlyUsedSeconds'] ?? 0) / quota['monthlyLimitSeconds'] * 100).round()
          : 0,
      showWarning: (quota['remainingSeconds'] ?? 0) <= 360 && (quota['remainingSeconds'] ?? 0) > 0,
      warningMessage: (quota['remainingSeconds'] ?? 0) <= 360
          ? '${((quota['remainingSeconds'] ?? 0) / 60).floor()} minutes remaining'
          : null,
    );
  }
}

/// Voice session info returned after successful start
class VoiceSessionInfo {
  final String dbSessionId;
  final String realtimeSessionId;
  final String model;
  final String voice;
  final VoiceQuota quota;

  VoiceSessionInfo({
    required this.dbSessionId,
    required this.realtimeSessionId,
    required this.model,
    required this.voice,
    required this.quota,
  });
}

/// Voice transcript entry
class VoiceTranscript {
  final String role; // 'user' or 'assistant'
  final String text;
  final DateTime timestamp;
  final bool isFinal; // true if complete, false if still streaming

  VoiceTranscript({
    required this.role,
    required this.text,
    required this.timestamp,
    this.isFinal = true,
  });

  /// Create a copy with updated text (for streaming updates)
  VoiceTranscript copyWith({String? text, bool? isFinal}) {
    return VoiceTranscript(
      role: role,
      text: text ?? this.text,
      timestamp: timestamp,
      isFinal: isFinal ?? this.isFinal,
    );
  }
}

/// Base exception for Voice AI errors
class VoiceAIException implements Exception {
  final String message;
  VoiceAIException(this.message);

  @override
  String toString() => message;
}

/// Exception when user needs Pro tier
class VoiceAITierRequiredException extends VoiceAIException {
  final String requiredTier;
  final String currentTier;

  VoiceAITierRequiredException(super.message, this.requiredTier, this.currentTier);
}

/// Exception when voice quota is exceeded
class VoiceAIQuotaExceededException extends VoiceAIException {
  final VoiceQuota quota;

  VoiceAIQuotaExceededException(super.message, this.quota);
}
