import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/realtime_websocket_service.dart';
import 'chat_screen.dart';

class VoiceChatScreen extends ConsumerStatefulWidget {
  const VoiceChatScreen({super.key});

  @override
  ConsumerState<VoiceChatScreen> createState() => _VoiceChatScreenState();
}

class _VoiceChatScreenState extends ConsumerState<VoiceChatScreen>
    with SingleTickerProviderStateMixin {
  final _messages = <ChatMessage>[];
  late AnimationController _pulseController;
  String _currentAiResponse = '';
  String _currentTranscription = '';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleVoiceChat() async {
    final voiceService = ref.read(realtimeWebSocketServiceProvider);
    
    if (voiceService.connectionState == VoiceConnectionState.disconnected) {
      try {
        await voiceService.connect(voice: 'marin');
        _listenToVoiceStreams();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start voice chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      await voiceService.disconnect();
    }
  }

  void _listenToVoiceStreams() {
    final voiceService = ref.read(realtimeWebSocketServiceProvider);
    
    // Listen to transcriptions
    voiceService.transcriptionStream.listen((transcript) {
      setState(() {
        _currentTranscription = transcript;
      });
    });

    // Listen to AI responses
    voiceService.aiResponseStream.listen((response) {
      setState(() {
        _currentAiResponse += response;
      });
    }, onDone: () {
      if (_currentAiResponse.isNotEmpty) {
        setState(() {
          _messages.add(ChatMessage(
            text: _currentAiResponse,
            isUser: false,
            timestamp: DateTime.now(),
          ));
          _currentAiResponse = '';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final voiceService = ref.watch(realtimeWebSocketServiceProvider);
    final isConnected = voiceService.connectionState == VoiceConnectionState.connected;
    final isConnecting = voiceService.connectionState == VoiceConnectionState.connecting;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ask the Bartender',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Voice & Chat',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          if (isConnected)
            IconButton(
              icon: Icon(
                voiceService.isMuted ? Icons.mic_off : Icons.mic,
                color: voiceService.isMuted ? Colors.red : Colors.green,
              ),
              onPressed: () => voiceService.toggleMute(),
            ),
        ],
      ),
      body: Column(
        children: [
          // Connection status
          if (isConnecting || isConnected)
            Container(
              color: isConnected ? Colors.green.shade900 : Colors.orange.shade900,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                children: [
                  if (isConnecting) ...[
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Connecting to voice service...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ] else ...[
                    const Icon(Icons.circle, size: 12, color: Colors.white),
                    const SizedBox(width: 8),
                    const Text(
                      'Voice chat active',
                      style: TextStyle(color: Colors.white),
                    ),
                    const Spacer(),
                    if (_currentTranscription.isNotEmpty)
                      Expanded(
                        child: Text(
                          _currentTranscription,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          
          // Messages
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + 
                (_currentTranscription.isNotEmpty ? 1 : 0) +
                (_currentAiResponse.isNotEmpty ? 1 : 0),
              itemBuilder: (context, index) {
                // Show current transcription
                if (_currentTranscription.isNotEmpty && 
                    index == _messages.length) {
                  return _ChatBubble(
                    message: ChatMessage(
                      text: _currentTranscription,
                      isUser: true,
                      timestamp: DateTime.now(),
                    ),
                    isTranscribing: true,
                  );
                }
                
                // Show current AI response
                if (_currentAiResponse.isNotEmpty && 
                    index == _messages.length + (_currentTranscription.isNotEmpty ? 1 : 0)) {
                  return _ChatBubble(
                    message: ChatMessage(
                      text: _currentAiResponse,
                      isUser: false,
                      timestamp: DateTime.now(),
                    ),
                    isGenerating: true,
                  );
                }
                
                return _ChatBubble(message: _messages[index]);
              },
            ),
          ),
          
          // Voice control button
          _buildVoiceControl(isConnected, isConnecting),
        ],
      ),
    );
  }

  Widget _buildVoiceControl(bool isConnected, bool isConnecting) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: GestureDetector(
          onTap: isConnecting ? null : _toggleVoiceChat,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = isConnected 
                ? 1.0 + (_pulseController.value * 0.1)
                : 1.0;
              
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: isConnected
                        ? [Colors.green.shade400, Colors.green.shade700]
                        : [Colors.purple.shade400, Colors.purple.shade700],
                    ),
                    boxShadow: isConnected
                      ? [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.5),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ]
                      : [],
                  ),
                  child: Icon(
                    isConnected ? Icons.stop : Icons.mic,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isTranscribing;
  final bool isGenerating;

  const _ChatBubble({
    required this.message,
    this.isTranscribing = false,
    this.isGenerating = false,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: message.isUser
              ? Theme.of(context).primaryColor.withOpacity(
                  isTranscribing ? 0.7 : 1.0,
                )
              : message.isError
                  ? Colors.red.shade900
                  : const Color(0xFF2A2A3E).withOpacity(
                      isGenerating ? 0.7 : 1.0,
                    ),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(message.isUser ? 16 : 4),
            bottomRight: Radius.circular(message.isUser ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontStyle: (isTranscribing || isGenerating) 
                  ? FontStyle.italic 
                  : FontStyle.normal,
              ),
            ),
            if (isTranscribing || isGenerating)
              const SizedBox(height: 4),
            if (isTranscribing)
              const Text(
                'Listening...',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            if (isGenerating)
              const Text(
                'Speaking...',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
