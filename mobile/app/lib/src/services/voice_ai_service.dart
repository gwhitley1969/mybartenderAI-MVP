import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
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

  // Transcripts collected during the session
  final List<VoiceTranscript> _transcripts = [];

  // Callbacks
  Function(VoiceAIState)? _onStateChange;
  Function(String, String, bool)? _onTranscript; // (role, text, isFinal)
  Function(VoiceQuota)? _onQuotaUpdate;

  // Buffer for accumulating streaming assistant response
  StringBuffer _currentAssistantResponse = StringBuffer();

  VoiceAIState _state = VoiceAIState.idle;
  VoiceAIState get state => _state;

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
      // Get local audio stream
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
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

      // Handle incoming audio from AI
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (event.track.kind == 'audio') {
          // AI is speaking - the audio will play automatically
          _setState(VoiceAIState.speaking);
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
          _setState(VoiceAIState.listening);
          break;

        case 'input_audio_buffer.speech_stopped':
          _setState(VoiceAIState.processing);
          break;

        case 'response.audio.started':
          _setState(VoiceAIState.speaking);
          break;

        case 'response.audio.done':
        case 'response.done':
          _setState(VoiceAIState.listening);
          break;

        case 'error':
          // Error message available in data['error']?['message']
          debugPrint('VoiceAIService: Received error from data channel: ${data['error']}');
          _setState(VoiceAIState.error);
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

    // Calculate duration
    _durationSeconds = DateTime.now().difference(_sessionStartTime!).inSeconds;

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
    } catch (e) {
      debugPrint('VoiceAIService: Error during cleanup: $e');
    }
  }

  void _setState(VoiceAIState newState) {
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
      monthlyLimitSeconds: quota['monthlyLimitSeconds'] ?? 1800,
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
      monthlyLimitSeconds: quota['monthlyLimitSeconds'] ?? 1800,
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
