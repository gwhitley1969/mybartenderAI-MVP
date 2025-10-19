import 'dart:io';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Creates a WebSocket connection with custom headers
class WebSocketConnection {
  static Future<WebSocketChannel> connect(
    Uri uri, {
    Map<String, String>? headers,
    List<String>? protocols,
  }) async {
    try {
      // Create HttpClient for custom headers
      final client = HttpClient();
      final request = await client.openUrl('GET', uri);
      
      // Add headers
      if (headers != null) {
        headers.forEach((key, value) {
          request.headers.add(key, value);
        });
      }
      
      // Add WebSocket headers
      request.headers
        ..set('Connection', 'Upgrade')
        ..set('Upgrade', 'websocket')
        ..set('Sec-WebSocket-Version', '13')
        ..set('Sec-WebSocket-Key', _generateWebSocketKey());
      
      if (protocols != null && protocols.isNotEmpty) {
        request.headers.set('Sec-WebSocket-Protocol', protocols.join(', '));
      }
      
      final response = await request.close();
      final socket = await response.detachSocket();
      
      return IOWebSocketChannel(socket);
    } catch (e) {
      throw Exception('Failed to connect WebSocket: $e');
    }
  }
  
  static String _generateWebSocketKey() {
    final random = List<int>.generate(16, (i) => 
      DateTime.now().millisecondsSinceEpoch * i % 256);
    return base64.encode(random);
  }
}

// Missing import
import 'dart:convert';
