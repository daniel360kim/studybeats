// open_ai_service.dart

import 'dart:typed_data';

import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flourish_web/secrets.dart';
import 'package:flourish_web/api/auth/auth_service.dart';
import 'package:uuid/uuid.dart';

class OpenAiService {
  final AuthService _authService;
  final OpenAI _openAi;

  List<Map<String, dynamic>> _conversationHistory = [];
  final List<String> _aiMessages = [];
  final List<String> _userMessages = [];
  bool _loadingResponse = false;

  OpenAiService()
      : _authService = AuthService(),
        _openAi = OpenAI.instance.build(
          token: OPENAI_PROJECT_API_KEY,
          baseOption: HttpSetup(receiveTimeout: const Duration(seconds: 120)),
          enableLog: true,
        );

  List<Map<String, dynamic>> get conversationHistory => _conversationHistory;
  List<String> get aiMessages => _aiMessages;
  List<String> get userMessages => _userMessages;
  bool get loadingResponse => _loadingResponse;

  Future<void> sendMessage(String message, {Uint8List? imageFile, String? imageUrl}) async {
    if (_loadingResponse) return;

    _loadingResponse = true;
    final uid = await _authService.getCurrentUserUid();

    _userMessages.add(message);
    _conversationHistory.add({'role': 'user', 'content': message});

    if (imageFile != null && imageUrl != null) {
      _conversationHistory.add({
        'role': 'user',
        'content': [
          {'type': 'text', 'text': message},
          {'type': 'image_url', 'image_url': {'url': imageUrl}}
        ]
      });
    }

    final request = ChatCompleteText(
      user: uid,
      messages: _conversationHistory,
      maxToken: 1000,
      model: Gpt4OMiniChatModel(),
    );

    final response = await _openAi.onChatCompletion(request: request);

    if (response != null && response.choices.isNotEmpty) {
      final aiMessage = response.choices.first.message?.content ?? '';
      _aiMessages.add(aiMessage);
      _conversationHistory.add({
        'role': 'assistant',
        'content': aiMessage,
      });
    }

    _loadingResponse = false;
  }

  Future<String?> uploadImageAndGetUrl(Uint8List file) async {
    final fileName = const Uuid().v4();
    final storageRef = FirebaseStorage.instance.ref().child('images/$fileName');
    await storageRef.putData(file);
    return await storageRef.getDownloadURL();
  }
}
