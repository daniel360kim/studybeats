import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flourish_web/log_printer.dart';
import 'package:flourish_web/studyroom/widgets/screens/aichat/aichat.dart';

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
  late final CollectionReference _conversationHistoryCollection;

  Future<void> init() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _logger.e('User is not logged in');
      throw Exception('User is not logged in');
    }

    _conversationHistoryCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(user.email)
        .collection('conversationHistory');

    _logger.i('OpenAI Firebase Service initialized');
  }

  Future<void> addToConversationHistory(Map<String, dynamic> message) async {
    try {
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
}
