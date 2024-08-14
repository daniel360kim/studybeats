import 'dart:typed_data';

import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:flourish_web/api/auth/auth_service.dart';
import 'package:flourish_web/log_printer.dart';
import 'package:flourish_web/secrets.dart';
import 'package:flourish_web/studyroom/widgets/screens/aichat/aichat.dart';

class OpenAiService {
  final _logger = getLogger('OpenAi Service');

  final List<UserMessage> _userMessages = [];
  final List<String> _aiMessages = [];
  final List<Map<String, dynamic>> _conversationHistory = [];

  final OpenAI openAi = OpenAI.instance.build(
      token: OPENAI_PROJECT_API_KEY,
      baseOption: HttpSetup(receiveTimeout: const Duration(seconds: 120)),
      enableLog: true);

  final _authService = AuthService();


  Future<void> sendTextOnly(String userMessage) async {
    try {
      final uid = await _authService.getCurrentUserUid();
      _conversationHistory.add({'role': 'user', 'content': userMessage});
      _userMessages.add(UserMessage(userMessage, null));

      final request = ChatCompleteText(
          user: uid,
          messages: _conversationHistory,
          maxToken: 1000,
          model: Gpt4OMiniChatModel());

      final response = await openAi.onChatCompletion(request: request);

      for (var element in response!.choices) {
        _aiMessages.last = (element.message!.content);
        _conversationHistory
            .add({'role': 'assistant', 'content': element.message!.content});
      }
    } catch (e) {
      _logger.e('Unexpected error while sending text only: $e');
      rethrow;
    }
  }

  Future<void> sendImage(String userMessage, String imageUrl) async {
    final uid = await _authService.getCurrentUserUid();

    _conversationHistory.add({
      'role': 'user',
      'content': [
        {'type': 'text', 'text': userMessage},
        {
          'type': 'image_url',
          'image_url': {'url': imageUrl}
        }
      ]
    });

  }
}
