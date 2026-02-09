import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/purchase_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/voice_ai_provider.dart';
import '../../services/subscription_service.dart';
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
      VoiceAIState.tierRequired => (Icons.lock, 'Pro required', Colors.amber),
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
    final currentTier = ref.watch(currentTierProvider);
    final isPremium = currentTier == SubscriptionTier.premium;

    // Tier-specific messaging
    final title = isPremium ? 'Upgrade to Pro' : 'Pro Feature';
    final icon = isPremium ? Icons.arrow_upward : Icons.star;
    final message = isPremium
        ? 'You\'re a Premium member! Upgrade to Pro for 60 minutes of voice AI per month, or purchase minutes as needed.'
        : 'Voice AI is available for Pro members. Upgrade for 60 minutes per month included, or try it with a one-time purchase.';

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
          Row(
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                title,
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
            message,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 16),

          // Primary button: Upgrade to Pro
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _showProUpgradeSheet,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.amber.shade900,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                'Upgrade to Pro',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Secondary button: Buy 20 Minutes
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _purchaseVoiceMinutes,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Buy 20 Minutes - \$4.99'),
            ),
          ),
        ],
      ),
    );
  }

  /// Show Pro subscription options in a bottom sheet
  void _showProUpgradeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ProUpgradeSheet(
        onPurchaseComplete: () {
          // Refresh state after successful purchase
          ref.invalidate(voiceAINotifierProvider);
        },
      ),
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
            'You\'ve used all ${((quota?.monthlyLimitSeconds ?? 3600) / 60).round()} minutes '
            'of voice chat this month. Your quota resets on the 1st.',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _purchaseVoiceMinutes,
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

/// Bottom sheet for Pro subscription options
class _ProUpgradeSheet extends ConsumerStatefulWidget {
  final VoidCallback? onPurchaseComplete;

  const _ProUpgradeSheet({this.onPurchaseComplete});

  @override
  ConsumerState<_ProUpgradeSheet> createState() => _ProUpgradeSheetState();
}

class _ProUpgradeSheetState extends ConsumerState<_ProUpgradeSheet> {
  bool _isLoading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final offeringsAsync = ref.watch(subscriptionOfferingsProvider);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C2E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              const Text(
                'Upgrade to Pro',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // Description
              Text(
                'Get 60 minutes of Voice AI per month',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),

              // Error message
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.redAccent, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Loading or offerings
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(color: Colors.amber),
                )
              else
                offeringsAsync.when(
                  data: (offerings) => _buildOfferingOptions(offerings),
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(color: Colors.amber),
                  ),
                  error: (e, _) => _buildErrorState(e.toString()),
                ),

              const SizedBox(height: 16),

              // Cancel button
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey.shade400),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfferingOptions(Offerings? offerings) {
    if (offerings == null || offerings.current == null) {
      return _buildErrorState('No subscription options available');
    }

    // Find Pro packages from the current offering
    final packages = offerings.current!.availablePackages
        .where((p) =>
            p.storeProduct.identifier.contains('pro'))
        .toList();

    if (packages.isEmpty) {
      return _buildErrorState('Pro subscription not available');
    }

    // Sort to show monthly first, then yearly
    packages.sort((a, b) {
      final aIsMonthly = a.storeProduct.identifier.contains('monthly');
      final bIsMonthly = b.storeProduct.identifier.contains('monthly');
      if (aIsMonthly && !bIsMonthly) return -1;
      if (!aIsMonthly && bIsMonthly) return 1;
      return 0;
    });

    return Column(
      children: packages.map((package) {
        final isYearly = package.storeProduct.identifier.contains('yearly');
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _SubscriptionOptionTile(
            title: isYearly ? 'Pro Yearly' : 'Pro Monthly',
            price: package.storeProduct.priceString,
            period: isYearly ? '/year' : '/month',
            badge: isYearly ? 'Save 17%' : null,
            onTap: () => _purchasePackage(package),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildErrorState(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.cloud_off, color: Colors.grey.shade600, size: 48),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: Colors.grey.shade400),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _purchasePackage(Package package) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final subscriptionService = ref.read(subscriptionServiceProvider);
      final result = await subscriptionService.purchasePackage(package);

      if (result != null && mounted) {
        // Success! Close the sheet and notify
        Navigator.of(context).pop();
        widget.onPurchaseComplete?.call();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Welcome to Pro! You now have 60 voice minutes per month.'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        setState(() {
          _isLoading = false;
          // User cancelled - no error message needed
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }
}

/// Individual subscription option tile
class _SubscriptionOptionTile extends StatelessWidget {
  final String title;
  final String price;
  final String period;
  final String? badge;
  final VoidCallback onTap;

  const _SubscriptionOptionTile({
    required this.title,
    required this.price,
    required this.period,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.amber.shade700),
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                Colors.amber.shade900.withOpacity(0.2),
                Colors.orange.shade900.withOpacity(0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              badge!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '60 voice minutes/month',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    price,
                    style: TextStyle(
                      color: Colors.amber.shade400,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    period,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: Colors.amber.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
