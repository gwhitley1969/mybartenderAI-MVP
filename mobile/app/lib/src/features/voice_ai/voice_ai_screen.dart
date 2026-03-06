import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/purchase_provider.dart';
import '../../providers/voice_ai_provider.dart';
import '../../services/voice_ai_service.dart';
import '../subscription/subscription_sheet.dart';
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
  bool _hasShownLowMinutesModal = false;

  @override
  void dispose() {
    // End active session when screen is unmounted (e.g., system back gesture)
    // This ensures the /v1/voice/usage POST fires even if PopScope didn't trigger
    final state = ref.read(voiceAINotifierProvider);
    if (state.isConnected) {
      ref.read(voiceAINotifierProvider.notifier).endSession();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceAINotifierProvider);
    final quotaAsync = ref.watch(voiceQuotaProvider);

    // Low-minutes upsell modal (show once per screen visit for paid users)
    if (!_hasShownLowMinutesModal) {
      quotaAsync.whenData((quota) {
        if (quota.hasAccess &&
            quota.remainingMinutes < 5 &&
            quota.remainingMinutes > 0) {
          _hasShownLowMinutesModal = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showLowMinutesModal();
          });
        }
      });
    }

    return PopScope(
      canPop: !voiceState.isConnected,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldLeave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('End Voice Session?'),
            content: const Text(
                'Leaving will end your current voice session.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Stay'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Leave'),
              ),
            ],
          ),
        );
        if (shouldLeave == true && context.mounted) {
          await ref.read(voiceAINotifierProvider.notifier).endSession();
          if (context.mounted) {
            Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
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

            // Status indicator (updated for push-to-talk)
            _buildStatusIndicator(voiceState.voiceState, voiceState.isMicMuted),

            // Main voice button with push-to-talk support
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: VoiceButton(
                state: voiceState.voiceState,
                isLoading: voiceState.isLoading,
                isMuted: voiceState.isMicMuted,
                onTap: () => _handleVoiceButtonTap(voiceState),
                onMuteChanged: (muted) {
                  // Push-to-talk: control microphone mute state
                  final notifier = ref.read(voiceAINotifierProvider.notifier);
                  notifier.setMicrophoneMuted(muted);
                },
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
    ),
    );
  }

  Widget _buildStatusIndicator(VoiceAIState state, bool isMuted) {
    // Push-to-talk: Show different status when in listening state based on mute
    final (icon, text, color) = switch (state) {
      VoiceAIState.idle => (Icons.mic, 'Tap to start', Colors.grey),
      VoiceAIState.connecting => (Icons.sync, 'Connecting...', Colors.amber),
      VoiceAIState.listening => isMuted
          ? (Icons.mic_off, 'Hold to speak', Colors.grey)
          : (Icons.mic, 'Listening...', Colors.green),
      VoiceAIState.processing => (Icons.hourglass_empty, 'Thinking...', Colors.blue),
      VoiceAIState.speaking => (Icons.volume_up, 'AI Speaking...', Colors.purple),
      VoiceAIState.error => (Icons.error, 'Error occurred', Colors.red),
      VoiceAIState.quotaExhausted => (Icons.timer_off, 'Quota exhausted', Colors.orange),
      VoiceAIState.entitlementRequired => (Icons.lock, 'Subscription required', Colors.amber),
    };

    return Container(
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
    );
  }

  Future<void> _handleVoiceButtonTap(VoiceAISessionState state) async {
    if (state.isLoading) return;

    final notifier = ref.read(voiceAINotifierProvider.notifier);

    if (state.voiceState == VoiceAIState.idle ||
        state.voiceState == VoiceAIState.error) {
      // Start new session with user's bar inventory
      // Use .future to properly await the inventory data
      Map<String, List<String>>? formattedInventory;
      try {
        final inventory = await ref.read(inventoryProvider.future);

        if (inventory.isNotEmpty) {
          // Get all ingredient names - scanner doesn't set categories reliably
          // so we send all as a combined list
          final allIngredients = inventory
              .map((i) => i.ingredientName)
              .toList();

          formattedInventory = {
            'spirits': allIngredients,  // Send all as spirits for AI context
            'mixers': <String>[],       // Empty - AI will figure it out
          };

          debugPrint('[VOICE-AI] Sending ${allIngredients.length} ingredients to Voice AI');
          debugPrint('[VOICE-AI] Ingredients: ${allIngredients.join(", ")}');
        }
      } catch (e) {
        debugPrint('[VOICE-AI] Error loading inventory: $e');
        // Continue without inventory - voice AI will still work
      }

      notifier.startSession(inventory: formattedInventory);
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
                'Subscription Required',
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
            'Start your 3-day free trial to access AI features. After trial, \$4.99/month or \$49.99/year.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 16),

          // Primary button: Subscribe
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _showSubscriptionSheet,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.amber.shade900,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                'Subscribe',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Show subscription options in a bottom sheet
  void _showSubscriptionSheet() {
    showSubscriptionSheet(
      context,
      onPurchaseComplete: () {
        // Refresh state after successful purchase
        ref.invalidate(voiceAINotifierProvider);
        ref.invalidate(voiceQuotaProvider);
      },
    );
  }

  /// Purchase voice minutes add-on
  Future<void> _purchaseVoiceMinutes() async {
    final purchaseNotifier = ref.read(purchaseNotifierProvider.notifier);

    try {
      final success = await purchaseNotifier.purchaseVoiceMinutes();
      if (success && mounted) {
        // The purchase stream will handle the verification and quota refresh
        // Show a brief message that the purchase is being processed
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Processing purchase...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Purchase failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showLowMinutesModal() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A3E),
        title: const Text(
          'Running low on voice time!',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          '+60 minutes for \$3.99',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _purchaseVoiceMinutes();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Buy Now'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotaExhaustedPrompt(VoiceQuota? quota) {
    final isTrial = quota != null && quota.monthlyIncluded <= 10;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isTrial
            ? Colors.amber.shade900.withOpacity(0.3)
            : Colors.red.shade900.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTrial ? Colors.amber.shade700 : Colors.red.shade700,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                isTrial ? Icons.hourglass_empty : Icons.timer_off,
                color: isTrial ? Colors.amber : Colors.redAccent,
              ),
              const SizedBox(width: 8),
              Text(
                isTrial ? 'Trial Minutes Used' : 'Voice Minutes Exhausted',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isTrial
                ? 'You\'ve used your ${quota.monthlyIncluded} trial minutes. Subscribe to get 60 minutes per month.'
                : 'You\'ve used all your voice minutes this cycle. Buy more to continue.',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 12),
          if (isTrial)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _showSubscriptionSheet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Subscribe for 60 min/month',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            )
          else
            ElevatedButton(
              onPressed: _purchaseVoiceMinutes,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Buy 60 Minutes — \$3.99'),
            ),
        ],
      ),
    );
  }
}

