import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/ask_bartender_api.dart';
import '../../providers/inventory_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

class AskBartenderScreen extends ConsumerStatefulWidget {
  const AskBartenderScreen({super.key});

  @override
  ConsumerState<AskBartenderScreen> createState() => _AskBartenderScreenState();
}

class _AskBartenderScreenState extends ConsumerState<AskBartenderScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <ChatMessage>[];
  String? _conversationId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Add welcome message
    _messages.add(ChatMessage(
      text: "Hello! I'm your AI Bartender. I can help you discover cocktails based on what you have in your bar, teach you new recipes, or answer any cocktail-related questions. What can I help you with today?",
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(ChatMessage(
        text: message,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      final api = ref.read(askBartenderApiProvider);

      // Get user's inventory for context
      final userInventoryAsync = ref.read(inventoryProvider);
      BartenderInventory? inventory;

      // Handle AsyncValue from FutureProvider
      userInventoryAsync.whenData((userInventory) {
        if (userInventory.isNotEmpty) {
          // Categorize ingredients
          final spirits = <String>[];
          final mixers = <String>[];

          for (final item in userInventory) {
            final cat = item.category?.toLowerCase() ?? '';
            // Simple categorization - you can enhance this
            if (cat.contains('spirit') ||
                cat.contains('liqueur') ||
                cat.contains('whiskey') ||
                cat.contains('vodka') ||
                cat.contains('rum') ||
                cat.contains('gin') ||
                cat.contains('tequila') ||
                cat.contains('brandy')) {
              spirits.add(item.ingredientName);
            } else {
              mixers.add(item.ingredientName);
            }
          }

          inventory = BartenderInventory(
            spirits: spirits,
            mixers: mixers,
          );
        }
      });

      final response = await api.ask(
        message: message,
        inventory: inventory,
        conversationId: _conversationId,
      );

      setState(() {
        _conversationId = response.conversationId;
        _messages.add(ChatMessage(
          text: response.response,
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (e) {
      print('Error sending message: $e');
      setState(() {
        _messages.add(ChatMessage(
          text: 'Sorry, I encountered an error. Please try again later.',
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        ));
        _isLoading = false;
      });
    }
  }

  void _scrollToBottom() {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI Bartender',
              style: AppTypography.heading4.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'Your personal cocktail expert',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
            onPressed: () {
              setState(() {
                _messages.clear();
                _conversationId = null;
                _messages.add(ChatMessage(
                  text: "Hello! I'm your AI Bartender. How can I help you today?",
                  isUser: false,
                  timestamp: DateTime.now(),
                ));
              });
            },
            tooltip: 'Clear chat',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isLoading) {
                  return const _TypingIndicator();
                }
                return _ChatBubble(message: _messages[index]);
              },
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: AppTypography.bodyLarge.copyWith(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Ask me anything about cocktails...',
                hintStyle: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
                filled: true,
                fillColor: AppColors.backgroundPrimary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            backgroundColor: AppColors.primaryPurple,
            radius: 24,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
  });
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              backgroundColor: AppColors.primaryPurple,
              radius: 16,
              child: const Icon(
                Icons.local_bar,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primaryPurple : AppColors.cardBackground,
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
                    message.text,
                    style: AppTypography.bodyLarge.copyWith(
                      color: isUser ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  if (message.isError)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 16,
                            color: AppColors.error.withOpacity(0.8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Error',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.error.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: AppColors.primaryPurpleLight,
              radius: 16,
              child: const Icon(
                Icons.person,
                size: 20,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primaryPurple,
            radius: 16,
            child: const Icon(
              Icons.local_bar,
              size: 20,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(1),
                const SizedBox(width: 4),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + (index * 200)),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.primaryPurple.withOpacity(0.3 + (0.5 * value)),
            shape: BoxShape.circle,
          ),
        );
      },
      onEnd: () {
        // Loop animation
      },
    );
  }
}
