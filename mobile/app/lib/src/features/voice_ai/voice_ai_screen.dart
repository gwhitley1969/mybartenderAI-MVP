import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/purchase_provider.dart';
import '../../providers/subscription_provider.dart';
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
                'Subscriber Feature',
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
            'Voice AI is available for subscribers. Subscribe for 60 minutes per month included, or try it with a 3-day free trial.',
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _SubscriptionSheet(
        onPurchaseComplete: () {
          // Refresh state after successful purchase
          ref.invalidate(voiceAINotifierProvider);
          ref.invalidate(voiceQuotaProvider);
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
          '+60 minutes for \$5.99',
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
                'Voice Minutes Exhausted',
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
            'You\'ve used all your voice minutes this cycle. Buy more to continue.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _purchaseVoiceMinutes,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Buy 60 Minutes — \$5.99'),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet for subscription options
class _SubscriptionSheet extends ConsumerStatefulWidget {
  final VoidCallback? onPurchaseComplete;

  const _SubscriptionSheet({this.onPurchaseComplete});

  @override
  ConsumerState<_SubscriptionSheet> createState() => _SubscriptionSheetState();
}

class _SubscriptionSheetState extends ConsumerState<_SubscriptionSheet> {
  bool _isLoading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final offeringsAsync = ref.watch(subscriptionOfferingsProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                'Subscribe',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // Description
              Text(
                'Unlock the full bartender experience',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 20),

              // Feature list
              _buildFeatureRow(Icons.mic, 'Voice AI conversations'),
              _buildFeatureRow(Icons.auto_awesome, 'AI cocktail concierge'),
              _buildFeatureRow(Icons.camera_alt, 'Smart Scanner'),
              _buildFeatureRow(Icons.local_bar, 'Unlimited cocktail access'),
              const SizedBox(height: 20),

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

              const SizedBox(height: 12),

              // Compliance text
              Text(
                'Trial auto-converts to \$9.99/month unless canceled before trial ends.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              // Restore purchases link
              TextButton(
                onPressed: _restorePurchases,
                child: Text(
                  'Restore Purchases',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                ),
              ),

              // Cancel button
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.amber.shade400, size: 18),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferingOptions(Offerings? offerings) {
    if (offerings == null || offerings.current == null) {
      return _buildErrorState('No subscription options available');
    }

    // Show ALL available packages from the current offering
    final packages = offerings.current!.availablePackages.toList();

    if (packages.isEmpty) {
      return _buildErrorState('No subscription options available');
    }

    // Sort: monthly first, then yearly
    packages.sort((a, b) {
      final aIsMonthly = a.storeProduct.identifier.contains('monthly');
      final bIsMonthly = b.storeProduct.identifier.contains('monthly');
      if (aIsMonthly && !bIsMonthly) return -1;
      if (!aIsMonthly && bIsMonthly) return 1;
      return 0;
    });

    return Column(
      children: packages.map((package) {
        final isYearly = package.storeProduct.identifier.contains('yearly') ||
            package.storeProduct.identifier.contains('annual');
        final isMonthly = !isYearly;

        if (isMonthly) {
          // Monthly with trial — primary CTA
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildMonthlyTile(package),
          );
        } else {
          // Annual — secondary CTA with savings badge
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildAnnualTile(package),
          );
        }
      }).toList(),
    );
  }

  Widget _buildMonthlyTile(Package package) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _purchasePackage(package),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.amber.shade700, width: 2),
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                Colors.amber.shade900.withOpacity(0.3),
                Colors.orange.shade900.withOpacity(0.15),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              const Text(
                'Start 3-Day Free Trial',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Then ${package.storeProduct.priceString}/month. Cancel anytime.',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnnualTile(Package package) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _purchasePackage(package),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade700),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${package.storeProduct.priceString}/year',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Save over 15%',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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

  Future<void> _restorePurchases() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final subscriptionService = ref.read(subscriptionServiceProvider);
      final result = await subscriptionService.restorePurchases();

      if (mounted) {
        setState(() => _isLoading = false);

        if (result != null) {
          Navigator.of(context).pop();
          widget.onPurchaseComplete?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Purchases restored successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No purchases found to restore.'),
            ),
          );
        }
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
            content: Text('Welcome! You now have 60 voice minutes per month.'),
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
