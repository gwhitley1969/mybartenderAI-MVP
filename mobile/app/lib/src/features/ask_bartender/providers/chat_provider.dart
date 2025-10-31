import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';
import '../../../services/ask_bartender_service.dart';
import '../../../providers/inventory_provider.dart';

/// Provider for the AskBartenderService
final askBartenderServiceProvider = Provider<AskBartenderService>((ref) {
  return AskBartenderService();
});

/// State notifier for managing chat conversation state
class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  final AskBartenderService _service;
  final Ref _ref;

  ChatNotifier(this._service, this._ref) : super([
    ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: "Hello! I'm your AI Bartender. I can help you discover cocktails based on what you have in your bar, teach you new recipes, or answer any cocktail-related questions. What can I help you with today?",
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

    // Add loading message
    final loadingMessage = ChatMessage(
      id: '${DateTime.now().millisecondsSinceEpoch}_loading',
      content: '',
      isUser: false,
      timestamp: DateTime.now(),
      isLoading: true,
    );
    state = [...state, loadingMessage];

    try {
      // Get user's inventory for context
      final inventory = _ref.read(inventoryProvider);
      final inventoryContext = inventory.isNotEmpty
          ? 'User has these ingredients: ${inventory.map((i) => i.name).join(', ')}'
          : 'User has not added any ingredients to their bar yet.';

      // Send message to API
      final response = await _service.askBartender(
        message: message,
        context: inventoryContext,
      );

      // Remove loading message and add response
      state = [
        ...state.where((m) => !m.isLoading),
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: response,
          isUser: false,
          timestamp: DateTime.now(),
        ),
      ];
    } catch (e) {
      // Remove loading message and add error message
      state = [
        ...state.where((m) => !m.isLoading),
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: 'Sorry, I encountered an error. Please try again.',
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        ),
      ];
      print('Error sending message: $e');
    }
  }

  void clearChat() {
    state = [
      ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: "Hello! I'm your AI Bartender. How can I help you today?",
        isUser: false,
        timestamp: DateTime.now(),
      ),
    ];
  }
}

/// Provider for chat messages
final chatProvider = StateNotifierProvider<ChatNotifier, List<ChatMessage>>((ref) {
  final service = ref.watch(askBartenderServiceProvider);
  return ChatNotifier(service, ref);
});