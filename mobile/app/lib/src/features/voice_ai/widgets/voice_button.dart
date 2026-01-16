import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/voice_ai_service.dart';

/// Animated voice button with push-to-talk functionality
///
/// Tap behavior:
/// - When idle: Starts a new session
/// - When in session: Quick tap ends the session
///
/// Press-and-hold behavior (during active session):
/// - Press down: Unmutes microphone (starts listening)
/// - Release: Mutes microphone (triggers AI response)
///
/// Uses Listener for raw pointer events to avoid gesture conflicts.
class VoiceButton extends StatefulWidget {
  final VoiceAIState state;
  final bool isLoading;
  final bool isMuted; // Push-to-talk: true = not listening
  final VoidCallback onTap; // Start/end session
  final ValueChanged<bool>? onMuteChanged; // Push-to-talk mute control

  const VoiceButton({
    super.key,
    required this.state,
    required this.isLoading,
    required this.onTap,
    this.isMuted = true,
    this.onMuteChanged,
  });

  @override
  State<VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends State<VoiceButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  // Track if button is currently pressed (for visual feedback)
  bool _isPressed = false;

  // Track press start time for distinguishing tap vs hold
  DateTime? _pressStartTime;

  // Threshold for "quick tap" to end session (milliseconds)
  static const int _tapThresholdMs = 250;

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

    // Animate based on state AND mute status
    // Only pulse when actively listening (not muted) or AI is speaking
    final shouldAnimate = (widget.state == VoiceAIState.listening && !widget.isMuted) ||
        widget.state == VoiceAIState.speaking;

    if (shouldAnimate) {
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

  /// Check if we're in an active session that supports push-to-talk
  bool get _canPushToTalk =>
      widget.state == VoiceAIState.listening ||
      widget.state == VoiceAIState.speaking ||
      widget.state == VoiceAIState.processing;

  /// Check if we're in idle/error state where tap starts a session
  bool get _isIdleState =>
      widget.state == VoiceAIState.idle ||
      widget.state == VoiceAIState.error ||
      widget.state == VoiceAIState.quotaExhausted ||
      widget.state == VoiceAIState.tierRequired;

  void _handlePointerDown(PointerDownEvent event) {
    _pressStartTime = DateTime.now();

    if (_isIdleState) {
      // In idle state, we'll handle tap on release
      setState(() => _isPressed = true);
      HapticFeedback.lightImpact();
      return;
    }

    if (_canPushToTalk) {
      // In active session, start listening immediately
      setState(() => _isPressed = true);
      HapticFeedback.mediumImpact();

      // Unmute (start listening)
      widget.onMuteChanged?.call(false);
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (!_isPressed) return;

    final pressDuration = _pressStartTime != null
        ? DateTime.now().difference(_pressStartTime!).inMilliseconds
        : 0;

    setState(() => _isPressed = false);
    _pressStartTime = null;

    if (_isIdleState) {
      // Quick tap in idle state starts session
      widget.onTap();
      return;
    }

    if (_canPushToTalk) {
      // In active session:
      // - Quick tap (<250ms) = end session
      // - Longer hold = push-to-talk release (mute and commit)
      if (pressDuration < _tapThresholdMs) {
        // Quick tap ends session
        HapticFeedback.lightImpact();
        widget.onTap();
      } else {
        // Push-to-talk release - mute and trigger AI response
        HapticFeedback.lightImpact();
        widget.onMuteChanged?.call(true);
      }
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (!_isPressed) return;

    setState(() => _isPressed = false);
    _pressStartTime = null;

    // If in push-to-talk mode, mute on cancel
    if (_canPushToTalk) {
      widget.onMuteChanged?.call(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, gradient, size) = _getButtonStyle();

    // Show pulse ring when actively listening or speaking
    final showPulse = (widget.state == VoiceAIState.listening && !widget.isMuted) ||
        widget.state == VoiceAIState.speaking;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Use Listener for raw pointer events - avoids gesture conflicts
        Listener(
          onPointerDown: _handlePointerDown,
          onPointerUp: _handlePointerUp,
          onPointerCancel: _handlePointerCancel,
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Outer pulse ring when actively listening/speaking
                  if (showPulse)
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

                  // Pressed indicator ring (shows when user is holding button)
                  if (_isPressed)
                    Container(
                      width: size + 20,
                      height: size + 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.greenAccent.withOpacity(0.8),
                          width: 3,
                        ),
                      ),
                    ),

                  // Main button
                  Transform.scale(
                    scale: _isPressed ? 0.95 : _scaleAnimation.value,
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: gradient,
                        boxShadow: [
                          BoxShadow(
                            color: gradient.colors.first.withOpacity(0.4),
                            blurRadius: _isPressed ? 30 : 20,
                            spreadRadius: _isPressed ? 5 : 2,
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
        ),

        // Hint text for push-to-talk
        if (_canPushToTalk) ...[
          const SizedBox(height: 16),
          Text(
            _isPressed
                ? 'Listening...'
                : (widget.state == VoiceAIState.speaking
                    ? 'AI speaking'
                    : 'Hold to talk'),
            style: TextStyle(
              color: _isPressed
                  ? Colors.greenAccent
                  : Colors.white.withOpacity(0.7),
              fontSize: 14,
              fontWeight: _isPressed ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap to end session',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  (IconData, LinearGradient, double) _getButtonStyle() {
    // When pressed (listening), show mic icon with green gradient
    if (_isPressed && _canPushToTalk) {
      return (
        Icons.mic,
        const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        115.0, // Slightly larger when pressed
      );
    }

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
          // When muted (waiting), show muted mic icon with dimmer colors
          widget.isMuted ? Icons.mic_off : Icons.mic,
          widget.isMuted
              ? const LinearGradient(
                  colors: [Color(0xFF6B7280), Color(0xFF4B5563)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          110.0,
        ),
      VoiceAIState.processing => (
          Icons.hourglass_top,
          const LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          100.0,
        ),
      VoiceAIState.speaking => (
          Icons.volume_up,
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
