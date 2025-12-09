import 'package:flutter/material.dart';
import '../../../services/voice_ai_service.dart';

/// Animated voice button that changes based on voice state
class VoiceButton extends StatefulWidget {
  final VoiceAIState state;
  final bool isLoading;
  final VoidCallback onTap;

  const VoiceButton({
    super.key,
    required this.state,
    required this.isLoading,
    required this.onTap,
  });

  @override
  State<VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends State<VoiceButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(VoiceButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Animate based on state
    if (widget.state == VoiceAIState.listening ||
        widget.state == VoiceAIState.speaking) {
      _animationController.repeat(reverse: true);
    } else {
      _animationController.stop();
      _animationController.reset();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (icon, gradient, size) = _getButtonStyle();

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulse ring when listening/speaking
              if (widget.state == VoiceAIState.listening ||
                  widget.state == VoiceAIState.speaking)
                Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: size + 40,
                    height: size + 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: gradient.colors.first.withOpacity(0.2),
                    ),
                  ),
                ),

              // Main button
              Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: gradient,
                    boxShadow: [
                      BoxShadow(
                        color: gradient.colors.first.withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: widget.isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : Icon(
                          icon,
                          color: Colors.white,
                          size: size * 0.4,
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  (IconData, LinearGradient, double) _getButtonStyle() {
    return switch (widget.state) {
      VoiceAIState.idle => (
          Icons.mic,
          const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          100.0,
        ),
      VoiceAIState.connecting => (
          Icons.sync,
          const LinearGradient(
            colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          100.0,
        ),
      VoiceAIState.listening => (
          Icons.stop_rounded, // Stop icon - tap to end session
          const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF059669)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          110.0,
        ),
      VoiceAIState.processing => (
          Icons.stop_rounded, // Stop icon - tap to end session
          const LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          100.0,
        ),
      VoiceAIState.speaking => (
          Icons.stop_rounded, // Stop icon - tap to end session
          const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          110.0,
        ),
      VoiceAIState.error => (
          Icons.refresh,
          const LinearGradient(
            colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          100.0,
        ),
      VoiceAIState.quotaExhausted || VoiceAIState.tierRequired => (
          Icons.lock,
          const LinearGradient(
            colors: [Color(0xFF6B7280), Color(0xFF4B5563)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          100.0,
        ),
    };
  }
}

/// Helper widget for AnimatedBuilder
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
