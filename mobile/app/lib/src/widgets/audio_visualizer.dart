import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A widget that visualizes audio levels
class AudioVisualizer extends StatefulWidget {
  final double amplitude;
  final bool isActive;
  final Color? color;
  final double height;
  final int barCount;

  const AudioVisualizer({
    super.key,
    required this.amplitude,
    this.isActive = true,
    this.color,
    this.height = 60,
    this.barCount = 5,
  });

  @override
  State<AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<AudioVisualizer>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _controllers = List.generate(
      widget.barCount,
      (index) => AnimationController(
        duration: Duration(milliseconds: 300 + (index * 100)),
        vsync: this,
      ),
    );

    _animations = _controllers.map((controller) {
      return Tween<double>(
        begin: 0.2,
        end: 1.0,
      ).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
    }).toList();

    if (widget.isActive) {
      _startAnimations();
    }
  }

  void _startAnimations() {
    for (var i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 100), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  void _stopAnimations() {
    for (var controller in _controllers) {
      controller.stop();
      controller.value = 0.2;
    }
  }

  @override
  void didUpdateWidget(AudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _startAnimations();
      } else {
        _stopAnimations();
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(widget.barCount, (index) {
          return AnimatedBuilder(
            animation: _animations[index],
            builder: (context, child) {
              final baseHeight = widget.height * 0.3;
              final maxAdditionalHeight = widget.height * 0.7;
              final animValue = _animations[index].value;
              final amplitudeEffect = widget.amplitude.clamp(0.0, 1.0);
              final height = baseHeight + 
                (maxAdditionalHeight * animValue * amplitudeEffect);

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 4,
                height: height,
                decoration: BoxDecoration(
                  color: widget.color ?? Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

/// A circular audio level indicator
class AudioLevelIndicator extends StatelessWidget {
  final double level;
  final double size;
  final Color? color;
  final Color? backgroundColor;

  const AudioLevelIndicator({
    super.key,
    required this.level,
    this.size = 100,
    this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = color ?? Theme.of(context).primaryColor;
    final bgColor = backgroundColor ?? primaryColor.withOpacity(0.2);

    return Container(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bgColor,
            ),
          ),
          // Animated level circle
          AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: size * (0.5 + (level.clamp(0.0, 1.0) * 0.5)),
            height: size * (0.5 + (level.clamp(0.0, 1.0) * 0.5)),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primaryColor.withOpacity(0.8),
            ),
          ),
          // Center icon
          Icon(
            Icons.mic,
            color: Colors.white,
            size: size * 0.3,
          ),
        ],
      ),
    );
  }
}
