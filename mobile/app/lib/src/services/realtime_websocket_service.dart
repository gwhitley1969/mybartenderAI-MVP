import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:audioplayers/audioplayers.dart';

import '../app/bootstrap.dart';
import 'audio_recorder_service.dart';
import 'websocket_connection.dart';

enum VoiceConnectionState {
  disconnected,
  connecting,
  connected,
  failed,
}

class RealtimeWebSocketService extends ChangeNotifier {
  RealtimeWebSocketService(this._dio);

  final Dio _dio;
  
  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubscription;
  final AudioRecorderService _audioRecorder = AudioRecorderService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _tokenRefreshTimer;
  StreamSubscription<Uint8List>? _audioStreamSubscription;
  
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
  
  final _audioBuffer = <int>[];
  String? _responseId;
  String? _itemId;

  // Request microphone permission
  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status == PermissionStatus.granted;
  }

  // Get ephemeral token from backend
  Future<Map<String, dynamic>> _getRealtimeToken({String voice = 'marin'}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/realtime/token-simple',  // Using simple endpoint temporarily
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
    _tokenRefreshTimer = Timer(const Duration(minutes: 5), () async {
      if (_connectionState == VoiceConnectionState.connected) {
        try {
          // In production, implement token refresh
          debugPrint('Token refresh needed');
        } catch (e) {
          debugPrint('Failed to refresh token: $e');
        }
      }
    });
  }

  // Connect to OpenAI Realtime API via WebSocket
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
      final token = tokenData['client_secret']['value'] as String;
      final model = tokenData['model'] as String;

      // Connect to WebSocket
      final wsUrl = Uri.parse(
        'wss://api.openai.com/v1/realtime?model=$model',
      );
      
      // Create WebSocket with authentication headers
      final headers = {
        'Authorization': 'Bearer $token',
        'OpenAI-Beta': 'realtime=v1',
      };
      
      _wsChannel = await WebSocketConnection.connect(
        wsUrl,
        headers: headers,
        protocols: ['realtime'],
      );

      // Wait for connection and send session configuration
      await Future.delayed(const Duration(milliseconds: 500));
      
      _sendEvent({
        'type': 'session.update',
        'session': {
          'voice': voice,
          'instructions': '''You are a sophisticated AI bartender for MyBartenderAI. 
          Be conversational, helpful, and engaging. Help users discover new cocktails 
          and elevate their home bartending experience. Keep responses concise and 
          natural for voice interaction.''',
          'input_audio_format': 'pcm16',
          'output_audio_format': 'pcm16',
          'turn_detection': {
            'type': 'server_vad',
            'threshold': 0.5,
            'prefix_padding_ms': 300,
            'silence_duration_ms': 500,
          },
          'modalities': ['text', 'audio'],
        },
      });

      // Listen to WebSocket events
      _wsSubscription = _wsChannel!.stream.listen(
        _handleWebSocketMessage,
        onError: (error) {
          debugPrint('WebSocket error: $error');
          _setConnectionState(VoiceConnectionState.failed);
        },
        onDone: () {
          debugPrint('WebSocket closed');
          _setConnectionState(VoiceConnectionState.disconnected);
        },
      );

      // Start audio recording
      await _startAudioRecording();

      _setConnectionState(VoiceConnectionState.connected);
    } catch (e) {
      debugPrint('Connection failed: $e');
      _setConnectionState(VoiceConnectionState.failed);
      rethrow;
    }
  }

  // Handle incoming WebSocket messages
  void _handleWebSocketMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final type = data['type'] as String?;

      debugPrint('Received event: $type');

      switch (type) {
        case 'session.created':
          debugPrint('Session created successfully');
          break;

        case 'conversation.item.created':
          final item = data['item'] as Map<String, dynamic>?;
          if (item?['role'] == 'user') {
            _handleUserTranscription(item!);
          }
          break;

        case 'response.created':
          _responseId = data['response']?['id'] as String?;
          break;

        case 'response.output_item.added':
          final item = data['item'] as Map<String, dynamic>?;
          _itemId = item?['id'] as String?;
          break;

        case 'response.audio_transcript.delta':
          final delta = data['delta'] as String?;
          if (delta != null) {
            _aiResponseController.add(delta);
          }
          break;

        case 'response.audio.delta':
          final audioDelta = data['delta'] as String?;
          if (audioDelta != null) {
            _handleAudioDelta(audioDelta);
          }
          break;

        case 'response.audio_transcript.done':
          final transcript = data['transcript'] as String?;
          if (transcript != null) {
            debugPrint('AI said: $transcript');
          }
          break;

        case 'response.done':
          debugPrint('Response completed');
          _playAccumulatedAudio();
          break;

        case 'error':
          final error = data['error'] as Map<String, dynamic>?;
          debugPrint('Error: ${error?['message']}');
          break;

        default:
          debugPrint('Unhandled event type: $type');
      }
    } catch (e) {
      debugPrint('Error handling WebSocket message: $e');
    }
  }

  // Handle user transcription
  void _handleUserTranscription(Map<String, dynamic> item) {
    final content = item['content'] as List<dynamic>?;
    if (content != null && content.isNotEmpty) {
      final firstContent = content[0] as Map<String, dynamic>;
      if (firstContent['type'] == 'input_text') {
        final transcript = firstContent['text'] as String?;
        if (transcript != null) {
          _currentTranscription = transcript;
          _transcriptionController.add(transcript);
          notifyListeners();
        }
      }
    }
  }

  // Handle audio delta (base64 encoded PCM16)
  void _handleAudioDelta(String base64Audio) {
    try {
      final audioBytes = base64Decode(base64Audio);
      _audioBuffer.addAll(audioBytes);
    } catch (e) {
      debugPrint('Error decoding audio: $e');
    }
  }

  // Play accumulated audio
  Future<void> _playAccumulatedAudio() async {
    if (_audioBuffer.isEmpty) return;

    try {
      // Convert PCM16 to WAV format
      final wavBytes = _createWavFromPcm16(_audioBuffer);
      
      // Play audio
      await _audioPlayer.play(BytesSource(wavBytes));
      
      // Clear buffer
      _audioBuffer.clear();
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }

  // Create WAV header for PCM16 data
  Uint8List _createWavFromPcm16(List<int> pcmData) {
    const int sampleRate = 24000; // OpenAI uses 24kHz
    const int numChannels = 1;
    const int bitsPerSample = 16;
    
    final int dataSize = pcmData.length;
    final int fileSize = dataSize + 36; // 36 = WAV header size - 8
    
    final header = ByteData(44);
    
    // RIFF header
    header.setUint8(0, 0x52); // 'R'
    header.setUint8(1, 0x49); // 'I'
    header.setUint8(2, 0x46); // 'F'
    header.setUint8(3, 0x46); // 'F'
    header.setUint32(4, fileSize, Endian.little);
    header.setUint8(8, 0x57); // 'W'
    header.setUint8(9, 0x41); // 'A'
    header.setUint8(10, 0x56); // 'V'
    header.setUint8(11, 0x45); // 'E'
    
    // fmt chunk
    header.setUint8(12, 0x66); // 'f'
    header.setUint8(13, 0x6D); // 'm'
    header.setUint8(14, 0x74); // 't'
    header.setUint8(15, 0x20); // ' '
    header.setUint32(16, 16, Endian.little); // fmt chunk size
    header.setUint16(20, 1, Endian.little); // audio format (PCM)
    header.setUint16(22, numChannels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * numChannels * bitsPerSample ~/ 8, Endian.little); // byte rate
    header.setUint16(32, numChannels * bitsPerSample ~/ 8, Endian.little); // block align
    header.setUint16(34, bitsPerSample, Endian.little);
    
    // data chunk
    header.setUint8(36, 0x64); // 'd'
    header.setUint8(37, 0x61); // 'a'
    header.setUint8(38, 0x74); // 't'
    header.setUint8(39, 0x61); // 'a'
    header.setUint32(40, dataSize, Endian.little);
    
    // Combine header and PCM data
    final wavData = Uint8List(44 + dataSize);
    wavData.setRange(0, 44, header.buffer.asUint8List());
    wavData.setRange(44, 44 + dataSize, pcmData);
    
    return wavData;
  }

  // Start audio recording and streaming
  Future<void> _startAudioRecording() async {
    try {
      // Start recording with the audio recorder service
      final audioStream = await _audioRecorder.startRecording(
        sampleRate: 24000,
        onStateChanged: (state) {
          debugPrint('Recording state changed: $state');
        },
      );

      // Listen to the audio stream and send to WebSocket
      _audioStreamSubscription = audioStream.listen(
        (data) {
          if (_connectionState == VoiceConnectionState.connected && !_isMuted) {
            // Convert audio data to base64 and send
            final base64Audio = base64Encode(data);
            _sendEvent({
              'type': 'input_audio_buffer.append',
              'audio': base64Audio,
            });
            
            // Debug: show audio is being sent
            debugPrint('Sent audio chunk: ${data.length} bytes');
          }
        },
        onError: (error) {
          debugPrint('Audio streaming error: $error');
        },
        onDone: () {
          debugPrint('Audio stream closed');
        },
      );

      debugPrint('Audio recording started successfully');
    } catch (e) {
      debugPrint('Error starting audio recording: $e');
      rethrow;
    }
  }

  // Send event to WebSocket
  void _sendEvent(Map<String, dynamic> event) {
    if (_wsChannel == null) return;
    
    final eventJson = jsonEncode(event);
    _wsChannel!.sink.add(eventJson);
    debugPrint('Sent event: ${event['type']}');
  }

  // Toggle mute
  void toggleMute() {
    _isMuted = !_isMuted;
    notifyListeners();
    
    if (_isMuted) {
      _sendEvent({'type': 'input_audio_buffer.clear'});
    }
  }

  // Send text message (for hybrid voice/text mode)
  Future<void> sendTextMessage(String message) async {
    if (_wsChannel == null || 
        _connectionState != VoiceConnectionState.connected) {
      throw Exception('Not connected to voice service');
    }

    _sendEvent({
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
    });
    
    // Trigger response generation
    _sendEvent({'type': 'response.create'});
  }

  // Disconnect and cleanup
  Future<void> disconnect() async {
    _tokenRefreshTimer?.cancel();
    _audioStreamSubscription?.cancel();
    _wsSubscription?.cancel();
    
    try {
      // Stop audio recording if active
      if (_audioRecorder.isRecording) {
        await _audioRecorder.stopRecording();
      }
      
      // Stop audio playback
      await _audioPlayer.stop();
      
      // Send stop event before closing
      if (_wsChannel != null) {
        _sendEvent({'type': 'input_audio_buffer.clear'});
        await Future.delayed(const Duration(milliseconds: 100));
        await _wsChannel!.sink.close();
      }
    } catch (e) {
      debugPrint('Error during disconnect: $e');
    }

    _wsChannel = null;
    _currentTranscription = null;
    _audioBuffer.clear();
    _responseId = null;
    _itemId = null;
    
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
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}

final realtimeWebSocketServiceProvider = ChangeNotifierProvider<RealtimeWebSocketService>((ref) {
  final dio = ref.watch(dioProvider);
  return RealtimeWebSocketService(dio);
});
