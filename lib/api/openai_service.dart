import 'dart:typed_data';

import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flourish_web/api/Stripe/subscription_service.dart';
import 'package:flourish_web/api/auth/auth_service.dart';
import 'package:flourish_web/log_printer.dart';
import 'package:flourish_web/secrets.dart';
import 'package:flutter/material.dart';
import 'package:chat_gpt_sdk/src/model/complete_text/response/usage.dart';

enum MessageType {
  aiResponse,
  userMessageTextOnly,
  userMessageWithImage,
}

class AiStorageMessage {
  final MessageType messageType;
  final String message;
  final String? imageUrl;

  AiStorageMessage({
    required this.messageType,
    required this.message,
    required this.imageUrl,
  });
}

class OpenaiService {
  final _logger = getLogger('OpenAI Firebase Service');
  final _stripeSubscriptionService = StripeSubscriptionService();
  final OpenAI openAi = OpenAI.instance.build(
    token: OPENAI_PROJECT_API_KEY,
    baseOption: HttpSetup(receiveTimeout: const Duration(seconds: 120)),
    enableLog: true,
  );

  final _authService = AuthService();

  late final String _uid;

  late final CollectionReference _openAiCollection;
  late final CollectionReference _conversationHistoryCollection;
  late final DocumentReference _tokenLimitDoc;

  int _tokenLimit = 10000; //set to the minimum limit by default

  Future<void> init() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _logger.e('User is not logged in');
      throw Exception('User is not logged in');
    }

    _openAiCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(user.email)
        .collection('openai');

    _conversationHistoryCollection =
        _openAiCollection.doc('initialConversation').collection('messages');

    _tokenLimitDoc = _openAiCollection.doc('initialConversation');

    await updateTokenLimit(); // Update token limit

    _uid = await _authService
        .getCurrentUserUid(); // TODO handle not being logged in exception

    _logger.i('OpenAI Firebase Service initialized');
  }

  Future<void> updateTokenLimit() async {
    _logger.i('Updating token limit');
    try {
      final product = await _stripeSubscriptionService.getActiveProduct();
      if (product.tokenLimit == null) {
        _logger.w('Token limit not found');
        _tokenLimit = 10000;
      } else {
        _logger.i('Token limit: ${product.tokenLimit}');
        _tokenLimit = product.tokenLimit!;
      }

      _logger.i('Token limit sent to Firestore');
    } catch (e) {
      _logger.e('Failed to update token limit: $e');
      rethrow;
    }
  }

  Future<void> addToConversationHistory(Map<String, dynamic> message) async {
    try {
      await updateTokenLimit(); // Update token limit
      _logger.i('Adding message to conversation history');
      // Add message to conversation history
      final aiMessage = convertMessage(message);
      await _addMessageToFirestore(aiMessage);

      _logger.i('Message added to conversation history');
    } catch (e) {
      _logger.e('Failed to add message to conversation history: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getConversationHistory() async {
    try {
      _logger.i('Getting conversation history');
      // Get conversation history
      final querySnapshot = await _conversationHistoryCollection
          .orderBy('timestamp', descending: false)
          .get();

      if (querySnapshot.docs.isEmpty) {
        _logger.i('No conversation history found');
        return [];
      } else {
        final List<Map<String, dynamic>> conversationHistory = [];
        for (var doc in querySnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          // add the data to the conversation history list except the timestamp
          late final Map<String, dynamic> message;
          if (data['image_url'] == null) {
            message = {
              'role': data['role'],
              'content': data['content'],
            };
          } else {
            message = {
              'role': data['role'],
              'content': [
                {
                  'type': 'text',
                  'text': data['content'] ?? ' ',
                },
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': data['image_url'],
                  },
                },
              ],
            };
          }
          conversationHistory.add(message);
        }
        _logger.i('Successfully retrieved conversation history');
        return conversationHistory;
      }
    } catch (e) {
      _logger.e('Failed to get conversation history: $e');
      rethrow;
    }
  }

// Converts the map from conversation history to an AiStorageMessage object that can be sent to firestore
  AiStorageMessage convertMessage(Map<String, dynamic> message) {
    switch (message['role']) {
      case 'user':
        if (message['content'] is List) {
          // Initialize variables to store the extracted text and image URL
          String textContent = ' ';
          String? imageUrl;

          // Iterate over the list to extract text and image URL
          for (var contentItem in message['content']) {
            if (contentItem['type'] == 'text') {
              textContent = contentItem['text'] ?? ' ';
            } else if (contentItem['type'] == 'image_url') {
              imageUrl = contentItem['image_url']['url'];
            }
          }

          // Determine the message type based on the presence of text and image URL
          if (imageUrl != null) {
            return AiStorageMessage(
              messageType: MessageType.userMessageWithImage,
              message: textContent,
              imageUrl: imageUrl,
            );
          } else {
            _logger.w('Image URL not found in user image message');
            return AiStorageMessage(
              messageType: MessageType.userMessageTextOnly,
              message: textContent,
              imageUrl: null,
            );
          }
        } else {
          final textContent = message['content'];
          return AiStorageMessage(
            messageType: MessageType.userMessageTextOnly,
            message: textContent,
            imageUrl: null,
          );
        }
      case 'assistant':
        return AiStorageMessage(
          messageType: MessageType.aiResponse,
          message: message['content'],
          imageUrl: null,
        );
      default:
        _logger.e('Unknown message role');
        throw Exception('Unknown message role');
    }
  }

// Sends the AiStorageMessage object to Firestore
  Future<void> _addMessageToFirestore(AiStorageMessage message) async {
    try {
      late final String role;
      switch (message.messageType) {
        case MessageType.aiResponse:
          role = 'assistant';
          break;
        case MessageType.userMessageTextOnly:
        case MessageType.userMessageWithImage:
          role = 'user';
          break;
        default:
          _logger.e('Unknown message type');
          throw Exception('Unknown message type');
      }

      _conversationHistoryCollection.add({
        'timestamp': FieldValue.serverTimestamp(),
        'role': role,
        'content': message.message,
        if (message.imageUrl != null) 'image_url': message.imageUrl,
      });
    } catch (e) {
      _logger.e('Failed to add message to Firestore: $e');
      rethrow;
    }
  }

  Future<void> clearConversationHistory() async {
    try {
      _logger.i('Clearing conversation history');
      // Clear conversation history
      final querySnapshot = await _conversationHistoryCollection.get();
      for (var doc in querySnapshot.docs) {
        await doc.reference.delete();
      }
      _logger.i('Conversation history cleared');
    } catch (e) {
      _logger.e('Failed to clear conversation history: $e');
      rethrow;
    }
  }

  Future<String> getAPIResponse(List<Map<String, dynamic>> messages) async {
    try {
      _logger.i('Starting request to OpenAI API');
      final request = ChatCompleteText(
        user: _uid,
        messages: messages,
        maxToken: 1000,
        model: Gpt4OMiniChatModel(),
      );

      final response = await openAi.onChatCompletion(request: request);

      _logger.i('Received response from OpenAI');

      if (response == null ||
          response.choices.first.message == null ||
          response.choices.first.message!.content.isEmpty) {
        _logger.e('Invalid response from OpenAI');
        throw Exception('Invalid response from OpenAI');
      }

      final usage = response.usage;

      if (usage == null) {
        _logger.e('Usage data not found in response');
        throw Exception('Usage data not found in response');
      }

      await updateTokenLogs(usage);

      return response.choices.first.message!.content;
    } catch (e) {
      _logger.e('Unexpected error sending message to API: $e');
      throw Exception('Failed to send message to OpenAI API: $e');
    }
  }

  //only logs, doesnt check for token limit
  Future<void> updateTokenLogs(Usage tokenUsage) async {
    try {
      // Update token usage for the conversation all time
      Usage currentTokenUsage = Usage(0, 0, 0);
      final tokenSnapshot =
          await _conversationHistoryCollection.doc('initialConversation').get();
      if (tokenSnapshot.exists) {
        final tokenData = tokenSnapshot.data() as Map<String, dynamic>;
        currentTokenUsage = Usage.fromJson(tokenData['tokenUsage']);
      } else {
        currentTokenUsage = Usage(0, 0, 0);
      }

      final updatedTokenUsage = Usage(
        currentTokenUsage.promptTokens! + tokenUsage.promptTokens!,
        currentTokenUsage.completionTokens! + tokenUsage.completionTokens!,
        currentTokenUsage.totalTokens! + tokenUsage.totalTokens!,
      );

      await _tokenLimitDoc.set({
        'tokenUsage': updatedTokenUsage.toJson(),
      }, SetOptions(merge: true));

      // Update token usage for the current day
      final today = DateTime.now();
      final todayTokenUsage = await _tokenLimitDoc
          .collection('tokenLogs')
          .doc(today.toString().substring(0, 10))
          .get();

      if (todayTokenUsage.exists) {
        final todayTokenData = todayTokenUsage.data() as Map<String, dynamic>;
        final todayTokenUsageData =
            Usage.fromJson(todayTokenData['tokenUsage']);
        final updatedTodayTokenUsage = Usage(
          todayTokenUsageData.promptTokens! + tokenUsage.promptTokens!,
          todayTokenUsageData.completionTokens! + tokenUsage.completionTokens!,
          todayTokenUsageData.totalTokens! + tokenUsage.totalTokens!,
        );

        await _tokenLimitDoc
            .collection('tokenLogs')
            .doc(today.toString().substring(0, 10))
            .set({
          'tokenUsage': updatedTodayTokenUsage.toJson(),
        });
      } else {
        await _tokenLimitDoc
            .collection('tokenLogs')
            .doc(today.toString().substring(0, 10))
            .set({
          'tokenUsage': tokenUsage.toJson(),
        });
      }
    } catch (e) {
      _logger.e('Failed to update token logs: $e');
      rethrow;
    }
  }
}
