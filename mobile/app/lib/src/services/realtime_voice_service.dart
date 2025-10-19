import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../app/bootstrap.dart';

enum VoiceConnectionState {
  disconnected,
  connecting,
  connected,
  failed,
}

class RealtimeVoiceService extends ChangeNotifier {
  RealtimeVoiceService(this._dio);

  final Dio _dio;
  
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  String? _currentToken;
  Timer? _tokenRefreshTimer;
  
  VoiceConnectionState _connectionState = VoiceConnectionState.disconnected;
  VoiceConnectionState get connectionState => _connectionState;
  
  bool _isMuted = false;
  bool get isMuted => _isMuted;
  
  String? _currentTranscription;
  String? get currentTranscription => _currentTranscription;
  
  final _transcriptionController = StreamController<String>.broadcast();
  Stream<String> get transcriptionStream => _transcriptionController.stream;
  
  final _aiResponseController = StreamController<String>.broadcast();
  Stream<String> get aiResponseStream => _aiResponseController.stream;

  // Request microphone permission
  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status == PermissionStatus.granted;
  }

  // Get ephemeral token from backend
  Future<Map<String, dynamic>> _getRealtimeToken({String voice = 'marin'}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/realtime/token-test',  // Using test endpoint temporarily
        data: {'voice': voice},
      );
      
      final clientSecret = response.data?['client_secret'] as Map<String, dynamic>?;
      if (clientSecret == null || clientSecret['value'] == null) {
        throw Exception('No client secret received from server');
      }
      
      // Schedule token refresh before expiration
      _scheduleTokenRefresh();
      
      return response.data!;
    } catch (e) {
      throw Exception('Failed to get realtime token: $e');
    }
  }

  void _scheduleTokenRefresh() {
    _tokenRefreshTimer?.cancel();
    // Refresh token 5 minutes before expiration
    _tokenRefreshTimer = Timer(const Duration(minutes: 55), () async {
      if (_connectionState == VoiceConnectionState.connected) {
        try {
          _currentToken = await _getRealtimeToken();
          // In a real implementation, we'd update the connection with the new token
        } catch (e) {
          debugPrint('Failed to refresh token: $e');
        }
      }
    });
  }

  // Initialize WebRTC connection
  Future<void> connect({String voice = 'marin'}) async {
    if (_connectionState == VoiceConnectionState.connected ||
        _connectionState == VoiceConnectionState.connecting) {
      return;
    }

    _setConnectionState(VoiceConnectionState.connecting);

    try {
      // Get microphone permission
      final hasPermission = await requestMicrophonePermission();
      if (!hasPermission) {
        throw Exception('Microphone permission denied');
      }

      // Get ephemeral token
      final tokenData = await _getRealtimeToken(voice: voice);
      _currentToken = tokenData['client_secret']['value'];

      // For WebSocket connection, we'll need to implement:
      // 1. WebSocket connection to wss://api.openai.com/v1/realtime
      // 2. Audio streaming via WebSocket
      // 3. Event handling for transcriptions and responses
      
      // For now, we'll use WebRTC as a placeholder
      // TODO: Implement WebSocket-based connection
      
      _setConnectionState(VoiceConnectionState.connected);
      
      // Simulate connection for testing
      debugPrint('Voice connection established with token');
      debugPrint('Voice selected: $voice');
      
    } catch (e) {
      debugPrint('Connection failed: $e');
      _setConnectionState(VoiceConnectionState.failed);
      rethrow;
    }
  }

  // Send SDP offer to OpenAI
  Future<String> _sendOfferToOpenAI(String sdp) async {
    final response = await Dio().post(
      'https://api.openai.com/v1/realtime/calls',
      data: sdp,
      options: Options(
        headers: {
          'Authorization': 'Bearer $_currentToken',
          'Content-Type': 'application/sdp',
        },
      ),
    );

    if (response.statusCode == 200) {
      return response.data as String;
    } else {
      throw Exception('Failed to get SDP answer: ${response.statusCode}');
    }
  }

  // Set up data channel for receiving transcriptions and AI responses
  void _setupDataChannel() {
    final dataChannelInit = RTCDataChannelInit()
      ..ordered = true;

    final dataChannel = _peerConnection!.createDataChannel(
      'realtime',
      dataChannelInit,
    );

    dataChannel.onMessage = (RTCDataChannelMessage message) {
      try {
        final data = jsonDecode(message.text);
        _handleServerEvent(data);
      } catch (e) {
        debugPrint('Failed to parse message: $e');
      }
    };

    dataChannel.onDataChannelState = (state) {
      debugPrint('Data channel state: $state');
    };
  }

  // Handle events from OpenAI Realtime API
  void _handleServerEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;
    
    switch (type) {
      case 'response.output_text.delta':
        final text = event['text'] as String?;
        if (text != null) {
          _aiResponseController.add(text);
        }
        break;
        
      case 'response.output_audio_transcript.delta':
        final transcript = event['transcript'] as String?;
        if (transcript != null) {
          _currentTranscription = transcript;
          _transcriptionController.add(transcript);
          notifyListeners();
        }
        break;
        
      case 'error':
        final error = event['error'] as Map<String, dynamic>?;
        debugPrint('Realtime API error: $error');
        break;
        
      default:
        debugPrint('Unhandled event type: $type');
    }
  }

  // Toggle mute
  void toggleMute() {
    if (_localStream == null) return;

    _isMuted = !_isMuted;
    _localStream!.getAudioTracks().forEach((track) {
      track.enabled = !_isMuted;
    });
    notifyListeners();
  }

  // Send text message (for hybrid voice/text mode)
  Future<void> sendTextMessage(String message) async {
    if (_peerConnection == null || 
        _connectionState != VoiceConnectionState.connected) {
      throw Exception('Not connected to voice service');
    }

    // In a real implementation, send via data channel
    final event = {
      'type': 'conversation.item.create',
      'item': {
        'type': 'message',
        'role': 'user',
        'content': [
          {
            'type': 'input_text',
            'text': message,
          }
        ],
      },
    };

    // Send via data channel
    debugPrint('Sending text message: $message');
  }

  // Disconnect and cleanup
  Future<void> disconnect() async {
    _tokenRefreshTimer?.cancel();
    
    try {
      await _localStream?.dispose();
      await _peerConnection?.close();
    } catch (e) {
      debugPrint('Error during disconnect: $e');
    }

    _localStream = null;
    _peerConnection = null;
    _currentToken = null;
    _currentTranscription = null;
    
    _setConnectionState(VoiceConnectionState.disconnected);
  }

  void _setConnectionState(VoiceConnectionState state) {
    _connectionState = state;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    _transcriptionController.close();
    _aiResponseController.close();
    super.dispose();
  }
}

final realtimeVoiceServiceProvider = ChangeNotifierProvider<RealtimeVoiceService>((ref) {
  final dio = ref.watch(dioProvider);
  return RealtimeVoiceService(dio);
});
