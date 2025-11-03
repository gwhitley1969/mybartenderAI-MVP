import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/ask_bartender_api.dart';
import '../../providers/ask_bartender_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/voice_provider.dart';
import '../../services/speech_service.dart';
import '../../services/tts_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

class VoiceBartenderScreen extends ConsumerStatefulWidget {
  const VoiceBartenderScreen({super.key});

  @override
  ConsumerState<VoiceBartenderScreen> createState() =>
      _VoiceBartenderScreenState();
}

class _VoiceBartenderScreenState extends ConsumerState<VoiceBartenderScreen>
    with SingleTickerProviderStateMixin {
  final List<ChatMessage> _messages = [];
  late AnimationController _pulseController;

  VoiceState _voiceState = VoiceState.idle;
  String _currentTranscript = '';
  String? _conversationId;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    // Initialize services
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    final speechService = ref.read(speechServiceProvider);
    final ttsService = ref.read(ttsServiceProvider);

    await speechService.initialize();
    await ttsService.initialize();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    // Stop any ongoing speech
    final ttsService = ref.read(ttsServiceProvider);
    ttsService.stop();
    super.dispose();
  }

  Future<void> _toggleVoiceInput() async {
    if (_voiceState == VoiceState.idle) {
      await _startListening();
    } else if (_voiceState == VoiceState.listening) {
      // User can tap to stop listening early
      final speechService = ref.read(speechServiceProvider);
      await speechService.stop();
    } else if (_voiceState == VoiceState.speaking) {
      // User can tap to stop AI response
      final ttsService = ref.read(ttsServiceProvider);
      await ttsService.stop();
      setState(() {
        _voiceState = VoiceState.idle;
      });
    }
  }

  Future<void> _startListening() async {
    final speechService = ref.read(speechServiceProvider);

    if (!speechService.isInitialized) {
      _showError('Speech recognition not available');
      return;
    }

    setState(() {
      _voiceState = VoiceState.listening;
      _currentTranscript = '';
    });

    String finalTranscript = '';

    await speechService.listen(
      onPartialResult: (transcript) {
        setState(() {
          _currentTranscript = transcript;
        });
      },
      onResult: (transcript) {
        finalTranscript = transcript;
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 2),
    );

    // Wait a bit for final result
    await Future.delayed(const Duration(milliseconds: 500));

    if (finalTranscript.isNotEmpty) {
      await _processUserInput(finalTranscript);
    } else {
      setState(() {
        _voiceState = VoiceState.idle;
        _currentTranscript = '';
      });
      _showError('Didn\'t catch that. Please try again.');
    }
  }

  Future<void> _processUserInput(String userText) async {
    // Add user message to conversation
    setState(() {
      _messages.add(ChatMessage(
        text: userText,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _voiceState = VoiceState.processing;
      _currentTranscript = '';
    });

    try {
      // Get user's inventory for context
      final inventoryAsync = ref.read(inventoryProvider);
      final inventory = inventoryAsync.valueOrNull ?? [];
      final inventoryList = inventory.map((item) => item.ingredientName).toList();

      // Call backend API
      final apiService = ref.read(askBartenderApiProvider);
      final response = await apiService.askBartender(
        query: userText,
        inventory: inventoryList,
        conversationId: _conversationId,
      );

      // Update conversation ID
      _conversationId = response.conversationId;

      // Add AI response to conversation
      setState(() {
        _messages.add(ChatMessage(
          text: response.response,
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _voiceState = VoiceState.speaking;
      });

      // Speak the response
      final ttsService = ref.read(ttsServiceProvider);
      await ttsService.speak(response.response);

      // Back to idle when done speaking
      setState(() {
        _voiceState = VoiceState.idle;
      });

    } catch (e) {
      setState(() {
        _voiceState = VoiceState.idle;
      });
      _showError('Failed to get response: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        title: Text('Voice Bartender', style: AppTypography.heading2),
        backgroundColor: AppColors.backgroundSecondary,
        actions: [
          if (_conversationId != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'New Conversation',
              onPressed: () {
                setState(() {
                  _conversationId = null;
                  _messages.clear();
                  _voiceState = VoiceState.idle;
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Status indicator
          if (_voiceState != VoiceState.idle)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(AppSpacing.sm),
              color: _getStatusColor(),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_voiceState == VoiceState.listening ||
                      _voiceState == VoiceState.processing)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    ),
                  SizedBox(width: AppSpacing.sm),
                  Text(
                    _getStatusText(),
                    style: AppTypography.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          // Current transcript (while listening)
          if (_voiceState == VoiceState.listening && _currentTranscript.isNotEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(AppSpacing.md),
              color: AppColors.backgroundSecondary,
              child: Text(
                _currentTranscript,
                style: AppTypography.bodyMedium.copyWith(
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          // Messages
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: EdgeInsets.all(AppSpacing.md),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _ChatBubble(message: _messages[index]);
                    },
                  ),
          ),

          // Voice control button
          _buildVoiceControl(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.mic,
              size: 80,
              color: AppColors.primaryPurple.withOpacity(0.5),
            ),
            SizedBox(height: AppSpacing.lg),
            Text(
              'Tap the mic to start',
              style: AppTypography.heading3,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              'Ask me about cocktails, ingredients,\nor how to make your favorite drinks!',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceControl() {
    final canInteract = _voiceState == VoiceState.idle ||
        _voiceState == VoiceState.listening ||
        _voiceState == VoiceState.speaking;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: GestureDetector(
          onTap: canInteract ? _toggleVoiceInput : null,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final isActive = _voiceState == VoiceState.listening;
              final scale = isActive
                  ? 1.0 + (_pulseController.value * 0.2)
                  : 1.0;

              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: _getMicColors(),
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: AppColors.primaryPurple.withOpacity(0.5),
                              blurRadius: 30,
                              spreadRadius: 10,
                            ),
                          ]
                        : [],
                  ),
                  child: Icon(
                    _getMicIcon(),
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  IconData _getMicIcon() {
    switch (_voiceState) {
      case VoiceState.listening:
        return Icons.mic;
      case VoiceState.processing:
        return Icons.hourglass_empty;
      case VoiceState.speaking:
        return Icons.volume_up;
      case VoiceState.idle:
        return Icons.mic_none;
    }
  }

  List<Color> _getMicColors() {
    switch (_voiceState) {
      case VoiceState.listening:
        return [AppColors.primaryPurple, AppColors.primaryPurple.withOpacity(0.6)];
      case VoiceState.processing:
        return [AppColors.warning, AppColors.warning.withOpacity(0.6)];
      case VoiceState.speaking:
        return [AppColors.success, AppColors.success.withOpacity(0.6)];
      case VoiceState.idle:
        return [AppColors.iconCirclePurple, AppColors.iconCirclePurple.withOpacity(0.6)];
    }
  }

  Color _getStatusColor() {
    switch (_voiceState) {
      case VoiceState.listening:
        return AppColors.primaryPurple;
      case VoiceState.processing:
        return AppColors.warning;
      case VoiceState.speaking:
        return AppColors.success;
      case VoiceState.idle:
        return AppColors.backgroundSecondary;
    }
  }

  String _getStatusText() {
    switch (_voiceState) {
      case VoiceState.listening:
        return 'Listening...';
      case VoiceState.processing:
        return 'Thinking...';
      case VoiceState.speaking:
        return 'Speaking...';
      case VoiceState.idle:
        return '';
    }
  }
}

enum VoiceState {
  idle,
  listening,
  processing,
  speaking,
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: AppSpacing.md),
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: message.isUser
              ? AppColors.primaryPurple
              : AppColors.backgroundSecondary,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(message.isUser ? 16 : 4),
            bottomRight: Radius.circular(message.isUser ? 4 : 16),
          ),
          border: Border.all(
            color: message.isUser
                ? AppColors.primaryPurple
                : AppColors.cardBorder,
          ),
        ),
        child: Text(
          message.text,
          style: AppTypography.bodyMedium,
        ),
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}
