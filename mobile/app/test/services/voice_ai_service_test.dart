import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mybartenderai/src/services/voice_ai_service.dart';

// Events use the shapes the Azure OpenAI Realtime API (GA) sends over the WebRTC
// data channel.
void main() {
  late VoiceAIService service;

  setUp(() {
    service = VoiceAIService(
      Dio(),
      getUserId: () async => 'user-1',
      getAccessToken: () async => 'id-token',
    );
  });

  tearDown(() => service.dispose());

  void receive(Map<String, dynamic> event) =>
      service.handleDataChannelMessage(jsonEncode(event));

  List<(String, String)> transcriptLines() =>
      service.transcripts.map((t) => (t.role, t.text)).toList();

  group('session request', () {
    test('tells the backend this app speaks the GA Realtime protocol', () {
      expect(VoiceAIService.sessionRequestBody(null), {'realtimeProtocol': 'ga'});
    });

    test('still carries the My Bar inventory', () {
      final inventory = {
        'spirits': ['Gin', 'Campari'],
        'mixers': <String>[],
      };

      expect(VoiceAIService.sessionRequestBody(inventory), {
        'inventory': inventory,
        'realtimeProtocol': 'ga',
      });
    });
  });

  group('GA event names', () {
    test('final AI transcript arrives as response.output_audio_transcript.done', () {
      receive({
        'event_id': 'event_2',
        'type': 'response.output_audio_transcript.done',
        'response_id': 'resp_1',
        'item_id': 'item_1',
        'output_index': 0,
        'content_index': 0,
        'transcript': 'Try a Negroni.',
      });

      expect(transcriptLines(), [('assistant', 'Try a Negroni.')]);
    });

    test('response.output_audio_transcript.delta events build the AI reply', () {
      for (final delta in ['Try a ', 'Negroni.']) {
        receive({
          'event_id': 'event_$delta',
          'type': 'response.output_audio_transcript.delta',
          'response_id': 'resp_1',
          'item_id': 'item_1',
          'output_index': 0,
          'content_index': 0,
          'delta': delta,
        });
      }
      receive({
        'event_id': 'event_3',
        'type': 'response.output_audio_transcript.done',
        'response_id': 'resp_1',
        'item_id': 'item_1',
        'output_index': 0,
        'content_index': 0,
      });

      expect(transcriptLines(), [('assistant', 'Try a Negroni.')]);
    });

    // Guard: the Preview names stay handled for one release (passes before and after).
    test('Preview transcript event names keep working', () {
      receive({'type': 'response.audio_transcript.done', 'transcript': 'Try a Negroni.'});

      expect(transcriptLines(), [('assistant', 'Try a Negroni.')]);
    });
  });

  group('error events', () {
    test('a rejected client event does not end the session', () {
      // User held push-to-talk and has just finished speaking
      service.setMicrophoneMuted(false);
      receive({'type': 'input_audio_buffer.speech_started'});
      receive({'type': 'input_audio_buffer.speech_stopped'});
      expect(service.state, VoiceAIState.processing);

      receive({
        'event_id': 'event_9',
        'type': 'error',
        'error': {
          'type': 'invalid_request_error',
          'code': 'unknown_parameter',
          'message': "Unknown parameter: 'session.turn_detection'.",
          'param': 'session.turn_detection',
        },
      });

      expect(service.state, VoiceAIState.listening);
    });
  });
}
