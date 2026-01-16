import 'package:flutter/material.dart';
import '../../../services/voice_ai_service.dart';

/// Scrollable view showing conversation transcripts
class TranscriptView extends StatefulWidget {
  final List<VoiceTranscript> transcripts;
  final VoiceAIState voiceState;

  const TranscriptView({
    super.key,
    required this.transcripts,
    required this.voiceState,
  });

  @override
  State<TranscriptView> createState() => _TranscriptViewState();
}

class _TranscriptViewState extends State<TranscriptView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(TranscriptView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-scroll when new messages arrive
    if (widget.transcripts.length > oldWidget.transcripts.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.transcripts.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: widget.transcripts.length + (widget.voiceState == VoiceAIState.processing ? 1 : 0),
      itemBuilder: (context, index) {
        // Show typing indicator if processing
        if (index == widget.transcripts.length && widget.voiceState == VoiceAIState.processing) {
          return _buildTypingIndicator();
        }

        final transcript = widget.transcripts[index];
        return _buildTranscriptBubble(transcript);
      },
    );
  }

  Widget _buildEmptyState() {
    // Use LayoutBuilder + SingleChildScrollView to handle large fonts/small screens
    // Content stays centered when it fits, scrolls when it overflows
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.mic_none,
                  size: 80,
                  color: Colors.grey.shade700,
                ),
                const SizedBox(height: 24),
                Text(
                  'Voice AI Bartender',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Text(
                    'Have a natural conversation about cocktails, recipes, and bar techniques!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // How to use instructions
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade800),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'How to use',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildInstructionRow(Icons.touch_app, 'Tap to start a session'),
                      const SizedBox(height: 8),
                      _buildInstructionRow(Icons.mic, 'Hold button to speak'),
                      const SizedBox(height: 8),
                      _buildInstructionRow(Icons.volume_up, 'Release to hear AI respond'),
                      const SizedBox(height: 8),
                      _buildInstructionRow(Icons.stop_circle_outlined, 'Quick tap to end session'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildSuggestionChips(),
                const SizedBox(height: 16), // Bottom padding for scroll
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInstructionRow(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionChips() {
    final suggestions = [
      'How do I make a Margarita?',
      'What cocktails can I make with vodka?',
      'Suggest a classic bourbon drink',
    ];

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: suggestions.map((suggestion) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade800,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade700),
          ),
          child: Text(
            suggestion,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 13,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTranscriptBubble(VoiceTranscript transcript) {
    final isUser = transcript.role == 'user';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF6366F1),
              child: const Icon(Icons.local_bar, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF6366F1)
                    : Colors.grey.shade800,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transcript.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(transcript.timestamp),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey.shade700,
              child: const Icon(Icons.person, size: 16, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF6366F1),
            child: const Icon(Icons.local_bar, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: const TypingIndicatorDots(),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

/// Animated typing indicator dots
class TypingIndicatorDots extends StatefulWidget {
  const TypingIndicatorDots({super.key});

  @override
  State<TypingIndicatorDots> createState() => _TypingIndicatorDotsState();
}

class _TypingIndicatorDotsState extends State<TypingIndicatorDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final offset = (index * 0.2);
            final value = ((_controller.value + offset) % 1.0);
            final opacity = 0.3 + (0.7 * (value < 0.5 ? value * 2 : (1 - value) * 2));

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.white70,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

/// Animation builder helper
class AnimatedBuilder extends StatelessWidget {
  final Animation<double> animation;
  final Widget Function(BuildContext, Widget?) builder;

  const AnimatedBuilder({
    super.key,
    required this.animation,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder0(
      animation: animation,
      builder: builder,
    );
  }
}

class AnimatedBuilder0 extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;

  const AnimatedBuilder0({
    super.key,
    required Animation<double> animation,
    required this.builder,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return builder(context, null);
  }
}
