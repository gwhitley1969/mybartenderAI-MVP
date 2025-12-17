import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/voice_ai_provider.dart';
import '../../services/voice_ai_service.dart';
import 'widgets/voice_button.dart';
import 'widgets/transcript_view.dart';
import 'widgets/quota_display.dart';

/// Main screen for Voice AI conversations
class VoiceAIScreen extends ConsumerStatefulWidget {
  const VoiceAIScreen({super.key});

  @override
  ConsumerState<VoiceAIScreen> createState() => _VoiceAIScreenState();
}

class _VoiceAIScreenState extends ConsumerState<VoiceAIScreen> {
  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceAINotifierProvider);
    final quotaAsync = ref.watch(voiceQuotaProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF1C1C2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C2E),
        title: const Text(
          'Voice AI Bartender',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Quota display in app bar
          quotaAsync.when(
            data: (quota) => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: QuotaChip(quota: voiceState.quota ?? quota),
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Quota warning banner if applicable
            if (voiceState.quota?.showWarning == true)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                color: Colors.orange.shade900,
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        voiceState.quota?.warningMessage ?? 'Low quota remaining',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),

            // Transcript view - scrollable conversation history
            Expanded(
              child: TranscriptView(
                transcripts: voiceState.transcripts,
                voiceState: voiceState.voiceState,
              ),
            ),

            // Status indicator
            _buildStatusIndicator(voiceState.voiceState),

            // Main voice button
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: VoiceButton(
                state: voiceState.voiceState,
                isLoading: voiceState.isLoading,
                onTap: () => _handleVoiceButtonTap(voiceState),
              ),
            ),

            // Error message - only show for actual errors, not tier/quota issues
            // which have their own dedicated UI prompts
            if (voiceState.error != null &&
                !voiceState.requiresUpgrade &&
                voiceState.voiceState != VoiceAIState.quotaExhausted)
              Padding(
                padding: const EdgeInsets.only(bottom: 16, left: 24, right: 24),
                child: Text(
                  voiceState.error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),

            // Upgrade prompt for non-Pro users
            if (voiceState.requiresUpgrade)
              _buildUpgradePrompt(),

            // Quota exhausted prompt
            if (voiceState.voiceState == VoiceAIState.quotaExhausted)
              _buildQuotaExhaustedPrompt(voiceState.quota),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(VoiceAIState state) {
    final (icon, text, color) = switch (state) {
      VoiceAIState.idle => (Icons.mic_off, 'Tap to talk', Colors.grey),
      VoiceAIState.connecting => (Icons.sync, 'Connecting...', Colors.amber),
      VoiceAIState.listening => (Icons.mic, 'Listening...', Colors.green),
      VoiceAIState.processing => (Icons.hourglass_empty, 'Thinking...', Colors.blue),
      VoiceAIState.speaking => (Icons.volume_up, 'Speaking...', Colors.purple),
      VoiceAIState.error => (Icons.error, 'Error occurred', Colors.red),
      VoiceAIState.quotaExhausted => (Icons.timer_off, 'Quota exhausted', Colors.orange),
      VoiceAIState.tierRequired => (Icons.lock, 'Pro required', Colors.amber),
    };

    // Show "tap microphone to stop" hint when session is active
    final bool isActive = state == VoiceAIState.listening ||
                          state == VoiceAIState.processing ||
                          state == VoiceAIState.speaking;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                text,
                style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        if (isActive)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Tap microphone to stop',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 13,
              ),
            ),
          ),
      ],
    );
  }

  void _handleVoiceButtonTap(VoiceAISessionState state) {
    if (state.isLoading) return;

    final notifier = ref.read(voiceAINotifierProvider.notifier);

    if (state.voiceState == VoiceAIState.idle ||
        state.voiceState == VoiceAIState.error) {
      // Start new session
      // TODO: Pass inventory from inventory provider if available
      notifier.startSession();
    } else if (state.isConnected) {
      // End current session
      notifier.endSession();
    }
  }

  Widget _buildUpgradePrompt() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade900, Colors.orange.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.star, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Pro Feature',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Voice AI conversations are available exclusively for Pro members. '
            'Upgrade to enjoy 120 minutes of voice chat per month.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              // TODO: Navigate to subscription screen
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.amber.shade900,
            ),
            child: const Text('Upgrade to Pro'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotaExhaustedPrompt(VoiceQuota? quota) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade900.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade700),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.timer_off, color: Colors.redAccent),
              SizedBox(width: 8),
              Text(
                'Monthly Quota Exhausted',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ve used all ${((quota?.monthlyLimitSeconds ?? 7200) / 60).round()} minutes '
            'of voice chat this month. Your quota resets on the 1st.',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              // TODO: Navigate to add-on purchase
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Add-on purchase coming soon!')),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white),
            ),
            child: const Text('Buy 20 More Minutes'),
          ),
        ],
      ),
    );
  }
}
