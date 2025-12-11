import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';
import '../../../services/ask_bartender_service.dart';
import '../../../providers/inventory_provider.dart';
import '../../../providers/auth_provider.dart';

/// Provider for the AskBartenderService
final askBartenderServiceProvider = Provider<AskBartenderService>((ref) {
  return AskBartenderService(
    authService: ref.watch(authServiceProvider),
  );
});

/// State notifier for managing chat conversation state - DEBUG VERSION
class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  final AskBartenderService _service;
  final Ref _ref;

  ChatNotifier(this._service, this._ref) : super([
    ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: "DEBUG MODE - I'll show you exactly what's happening with each request.",
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

    // Add debug info message
    final debugStartMessage = ChatMessage(
      id: '${DateTime.now().millisecondsSinceEpoch}_debug',
      content: '🔍 DEBUG: Starting API call...',
      isUser: false,
      timestamp: DateTime.now(),
    );
    state = [...state, debugStartMessage];

    try {
      // Get user's inventory for context
      final inventory = _ref.read(inventoryProvider);
      final inventoryContext = inventory.isNotEmpty
          ? 'User has these ingredients: ${inventory.map((i) => i.name).join(', ')}'
          : 'User has not added any ingredients to their bar yet.';

      // Add debug message about what we're sending
      final debugRequestMessage = ChatMessage(
        id: '${DateTime.now().millisecondsSinceEpoch}_debug2',
        content: '📤 Sending: "$message"\n📦 Context: $inventoryContext',
        isUser: false,
        timestamp: DateTime.now(),
      );
      state = [...state, debugRequestMessage];

      // Send message to API
      final response = await _service.askBartender(
        message: message,
        context: inventoryContext,
      );

      // Add success message with response
      state = [
        ...state,
        ChatMessage(
          id: '${DateTime.now().millisecondsSinceEpoch}_success',
          content: '✅ SUCCESS! Got response from GPT-4o-mini',
          isUser: false,
          timestamp: DateTime.now(),
        ),
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: response,
          isUser: false,
          timestamp: DateTime.now(),
        ),
      ];
    } catch (e) {
      // Show DETAILED error information
      final errorDetails = '''
❌ ERROR DETAILS:
Type: ${e.runtimeType}
Message: ${e.toString()}

Full error stack:
$e

This error came from the Flutter app, not the backend.
Check the console/logcat for more details.
''';

      state = [
        ...state,
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: errorDetails,
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        ),
      ];

      print('=== FULL ERROR DUMP ===');
      print('Error Type: ${e.runtimeType}');
      print('Error String: ${e.toString()}');
      print('Stack Trace:');
      print(StackTrace.current);
      print('=== END ERROR DUMP ===');
    }
  }

  void clearChat() {
    state = [
      ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: "DEBUG MODE - Ready to show detailed error information.",
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