import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';
import '../../../services/backend_service.dart';
import '../../../providers/backend_provider.dart';
import '../../../providers/inventory_provider.dart';

/// State notifier for managing chat conversation state
///
/// Uses BackendService with JWT ID token authentication.
/// Backend looks up user tier from database on each request.
class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  final BackendService _backendService;
  final Ref _ref;

  ChatNotifier(this._backendService, this._ref) : super([
    ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: "Hello! I'm your AI bartender. What can I help you make today?",
      isUser: false,
      timestamp: DateTime.now(),
    ),
  ]);

  Future<void> sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    // Add user message
    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: message,
      isUser: true,
      timestamp: DateTime.now(),
    );
    state = [...state, userMessage];

    try {
      // Get user's inventory for context (unwrap from AsyncValue)
      final inventoryAsync = _ref.read(inventoryProvider);
      final inventory = inventoryAsync.valueOrNull ?? [];

      // Build context with inventory information
      final Map<String, dynamic> context = {};
      if (inventory.isNotEmpty) {
        // Group ingredients by type for better AI context
        final spirits = inventory
            .where((i) => i.category == 'spirit' || i.category == 'liquor')
            .map((i) => i.ingredientName)
            .toList();
        final mixers = inventory
            .where((i) => i.category != 'spirit' && i.category != 'liquor')
            .map((i) => i.ingredientName)
            .toList();

        context['inventory'] = {
          'spirits': spirits,
          'mixers': mixers,
        };
      }

      // Send message to API using BackendService
      // This uses ID token for APIM validation
      // Backend looks up user tier from database
      final result = await _backendService.askBartender(message, context: context);

      // Add AI response
      state = [
        ...state,
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: result.response,
          isUser: false,
          timestamp: DateTime.now(),
        ),
      ];
    } catch (e) {
      // Handle errors gracefully
      String errorMessage = 'Sorry, I had trouble processing your request.';

      if (e.toString().contains('429') || e.toString().contains('quota')) {
        errorMessage = 'You\'ve reached your monthly limit. Please upgrade your plan or wait until next month.';
      } else if (e.toString().contains('401') || e.toString().contains('403')) {
        errorMessage = 'Please sign in again to continue our conversation.';
      } else if (e.toString().contains('timeout') || e.toString().contains('connection')) {
        errorMessage = 'I\'m having trouble connecting. Please check your internet and try again.';
      }

      state = [
        ...state,
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: errorMessage,
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        ),
      ];

      print('Chat error: $e');
    }
  }

  void clearChat() {
    state = [
      ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: "Hello! I'm your AI bartender. What can I help you make today?",
        isUser: false,
        timestamp: DateTime.now(),
      ),
    ];
  }
}

/// Provider for chat messages
///
/// Uses BackendService with JWT ID token authentication.
/// Backend validates user and looks up tier from database.
final chatProvider = StateNotifierProvider<ChatNotifier, List<ChatMessage>>((ref) {
  final backendService = ref.watch(backendServiceProvider);
  return ChatNotifier(backendService, ref);
});