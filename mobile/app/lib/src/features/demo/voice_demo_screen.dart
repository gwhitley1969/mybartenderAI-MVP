import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/realtime_websocket_service.dart';

class VoiceDemoScreen extends ConsumerStatefulWidget {
  const VoiceDemoScreen({super.key});

  @override
  ConsumerState<VoiceDemoScreen> createState() => _VoiceDemoScreenState();
}

class _VoiceDemoScreenState extends ConsumerState<VoiceDemoScreen> {
  final _textController = TextEditingController();
  final _messages = <DemoMessage>[];
  bool _isListening = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _connectVoice() async {
    final voiceService = ref.read(realtimeWebSocketServiceProvider);
    
    try {
      await voiceService.connect(voice: 'marin');
      
      // Listen to transcriptions
      voiceService.transcriptionStream.listen((transcript) {
        setState(() {
          if (_messages.isEmpty || !_messages.last.isUser) {
            _messages.add(DemoMessage(
              text: transcript,
              isUser: true,
              timestamp: DateTime.now(),
            ));
          } else {
            _messages.last.text = transcript;
          }
        });
      });

      // Listen to AI responses
      final responseBuffer = StringBuffer();
      voiceService.aiResponseStream.listen(
        (delta) {
          responseBuffer.write(delta);
          setState(() {
            if (_messages.isEmpty || _messages.last.isUser) {
              _messages.add(DemoMessage(
                text: responseBuffer.toString(),
                isUser: false,
                timestamp: DateTime.now(),
              ));
            } else {
              _messages.last.text = responseBuffer.toString();
            }
          });
        },
        onDone: () {
          responseBuffer.clear();
        },
      );

      setState(() {
        _isListening = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _disconnectVoice() async {
    final voiceService = ref.read(realtimeWebSocketServiceProvider);
    await voiceService.disconnect();
    setState(() {
      _isListening = false;
    });
  }

  void _sendTextMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final voiceService = ref.read(realtimeWebSocketServiceProvider);
    voiceService.sendTextMessage(text);

    setState(() {
      _messages.add(DemoMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
    });

    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final voiceService = ref.watch(realtimeWebSocketServiceProvider);
    final connectionState = voiceService.connectionState;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Voice Demo'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Chip(
              label: Text(
                connectionState.name.toUpperCase(),
                style: const TextStyle(fontSize: 12),
              ),
              backgroundColor: _getStateColor(connectionState),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection controls
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF16213E),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: connectionState == VoiceConnectionState.disconnected
                        ? _connectVoice
                        : null,
                    icon: const Icon(Icons.power),
                    label: const Text('Connect'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: connectionState == VoiceConnectionState.connected
                        ? _disconnectVoice
                        : null,
                    icon: const Icon(Icons.power_off),
                    label: const Text('Disconnect'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: connectionState == VoiceConnectionState.connected
                      ? () => voiceService.toggleMute()
                      : null,
                  icon: Icon(
                    voiceService.isMuted ? Icons.mic_off : Icons.mic,
                    color: voiceService.isMuted ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
          ),
          
          // Messages
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return Align(
                  alignment: message.isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: message.isUser
                          ? Colors.blue.shade700
                          : const Color(0xFF2A2A3E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(message.timestamp),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Text input for testing
          if (connectionState == VoiceConnectionState.connected)
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF16213E),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Type a message (for testing)',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                        filled: true,
                        fillColor: const Color(0xFF2A2A3E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _sendTextMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sendTextMessage,
                    icon: const Icon(Icons.send),
                    color: Colors.white,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _getStateColor(VoiceConnectionState state) {
    switch (state) {
      case VoiceConnectionState.connected:
        return Colors.green;
      case VoiceConnectionState.connecting:
        return Colors.orange;
      case VoiceConnectionState.failed:
        return Colors.red;
      case VoiceConnectionState.disconnected:
        return Colors.grey;
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class DemoMessage {
  String text;
  final bool isUser;
  final DateTime timestamp;

  DemoMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}
