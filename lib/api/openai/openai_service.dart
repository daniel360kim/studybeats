import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:studybeats/api/Stripe/subscription_service.dart';
import 'package:studybeats/api/auth/auth_service.dart';
import 'package:studybeats/log_printer.dart';
import 'package:studybeats/secrets.dart';
// Assuming tokenizer.dart is in the same directory or accessible via package import
import 'package:studybeats/studyroom/side_widgets/aichat/tokenizer.dart';

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
    this.imageUrl,
  });
}

class Usage {
  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;

  Usage(this.promptTokens, this.completionTokens, this.totalTokens);

  Usage.fromJson(Map<String, dynamic> json)
      : promptTokens = json['prompt_tokens'],
        completionTokens = json['completion_tokens'],
        totalTokens = json['total_tokens'];

  Map<String, dynamic> toJson() => {
        'prompt_tokens': promptTokens,
        'completion_tokens': completionTokens,
        'total_tokens': totalTokens,
      };
}

// New class to represent chat metadata
class ChatMetadata {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime lastModifiedAt;
  final String modelId; // OpenAI model ID like "gpt-4o-mini"

  ChatMetadata({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.lastModifiedAt,
    required this.modelId,
  });

  factory ChatMetadata.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    Map<String, dynamic> data = doc.data()!;
    return ChatMetadata(
      id: doc.id,
      title: data['title'] ?? 'Untitled Chat',
      createdAt: (data['createdAt'] as Timestamp? ?? Timestamp.now()).toDate(),
      lastModifiedAt:
          (data['lastModifiedAt'] as Timestamp? ?? Timestamp.now()).toDate(),
      modelId: data['model_id'] ?? 'gpt-4o-mini', // Default model
    );
  }
}

class OpenaiService {
  final _logger = getLogger('OpenAI Firebase Service');
  final _stripeSubscriptionService = StripeSubscriptionService();
  final client = OpenAIClient(apiKey: OPENAI_PROJECT_API_KEY);
  // Made tokenizer public
  final Tokenizer tokenizer = Tokenizer();

  final _authService = AuthService();
  String? _userEmail; // Store user email after login

  // References to user-specific Firestore paths
  DocumentReference? _userDocumentRef;
  DocumentReference?
      _tokenUsageSummaryDoc; // Points to users/{email}/openai_token_data/usage_summary

  int _tokenLimit = 10000; // Set to the minimum limit by default
  bool _tokenLimitExceeded = false;
  bool get tokenLimitExceeded => _tokenLimitExceeded;

  Future<void> init() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      _logger.e('User is not logged in or email is null');
      throw Exception('User is not logged in or email is null');
    }
    _userEmail = user.email!;

    _userDocumentRef =
        FirebaseFirestore.instance.collection('users').doc(_userEmail);
    // _tokenUsageSummaryDoc now correctly points to the document under which 'daily_logs' will be a subcollection
    _tokenUsageSummaryDoc =
        _userDocumentRef!.collection('openai_token_data').doc('usage_summary');

    await updateTokenLimit(); // Fetches limit based on new structure
    await checkTokenUsage(); // Checks usage based on new structure

    _logger
        .i('OpenAI Service initialized for multi-chat for user: $_userEmail');
  }

  // Helper to get the messages subcollection for a specific chat
  CollectionReference _messagesCollectionForChat(String chatId) {
    if (_userDocumentRef == null) {
      throw Exception("OpenaiService not initialized or user not logged in.");
    }
    return _userDocumentRef!
        .collection('openai_chats')
        .doc(chatId)
        .collection('messages');
  }

  // Helper to get the chat document reference
  DocumentReference _chatDocumentRef(String chatId) {
    if (_userDocumentRef == null) {
      throw Exception("OpenaiService not initialized or user not logged in.");
    }
    return _userDocumentRef!.collection('openai_chats').doc(chatId);
  }

  Future<void> updateTokenLimit() async {
    _logger.i('Updating token limit');
    if (_tokenUsageSummaryDoc == null) {
      _logger.e(
          "Token usage summary document reference is null. Service not initialized?");
      return;
    }
    try {
      final product = await _stripeSubscriptionService.getActiveProduct();
      if (product.tokenLimit == null) {
        _logger.w('Token limit not found in product');
        _tokenLimit = 1000; // Default fallback
      } else {
        _logger.i('Token limit from product: ${product.tokenLimit}');
        _tokenLimit = product.tokenLimit!;
      }
      _logger.i('Token limit updated: $_tokenLimit');
    } catch (e) {
      _logger.e('Failed to update token limit: $e');
    }
  }

  Future<void> addToConversationHistory(
      String chatId, Map<String, dynamic> messageData) async {
    if (_userDocumentRef == null) throw Exception("Service not initialized.");
    try {
      _logger.i('Adding message to conversation history for chat $chatId');
      final messagesCol = _messagesCollectionForChat(chatId);
      final aiMessage = convertMessage(messageData);

      await messagesCol.add({
        'timestamp': FieldValue.serverTimestamp(),
        'role': messageData['role'],
        'content': aiMessage.message,
        if (aiMessage.imageUrl != null) 'image_url': aiMessage.imageUrl,
      });

      await _chatDocumentRef(chatId)
          .update({'lastModifiedAt': FieldValue.serverTimestamp()});
      _logger.i('Message added to conversation history for chat $chatId');
    } catch (e) {
      _logger.e(
          'Failed to add message to conversation history for chat $chatId: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getConversationHistory(
      String chatId) async {
    if (_userDocumentRef == null) throw Exception("Service not initialized.");
    try {
      _logger.i('Getting conversation history for chat $chatId');
      final querySnapshot = await _messagesCollectionForChat(chatId)
          .orderBy('timestamp', descending: false)
          .get();

      if (querySnapshot.docs.isEmpty) {
        _logger.i('No conversation history found for chat $chatId');
        return [];
      } else {
        final List<Map<String, dynamic>> conversationHistory = [];
        for (var doc in querySnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
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
                {'type': 'text', 'text': data['content'] ?? ' '},
                {
                  'type': 'image_url',
                  'image_url': {'url': data['image_url']}
                },
              ],
            };
          }
          conversationHistory.add(message);
        }
        _logger
            .i('Successfully retrieved conversation history for chat $chatId');
        return conversationHistory;
      }
    } catch (e) {
      _logger.e('Failed to get conversation history for chat $chatId: $e');
      rethrow;
    }
  }

  AiStorageMessage convertMessage(Map<String, dynamic> message) {
    switch (message['role']) {
      case 'user':
        if (message['content'] is List) {
          String textContent = ' ';
          String? imageUrl;
          for (var contentItem in message['content']) {
            if (contentItem['type'] == 'text') {
              textContent = contentItem['text'] ?? ' ';
            } else if (contentItem['type'] == 'image_url') {
              imageUrl = contentItem['image_url']['url'];
            }
          }
          if (imageUrl != null) {
            return AiStorageMessage(
              messageType: MessageType.userMessageWithImage,
              message: textContent,
              imageUrl: imageUrl,
            );
          } else {
            return AiStorageMessage(
              messageType: MessageType.userMessageTextOnly,
              message: textContent,
              imageUrl: null,
            );
          }
        } else {
          final textContent = message['content'] as String? ?? '';
          return AiStorageMessage(
            messageType: MessageType.userMessageTextOnly,
            message: textContent,
            imageUrl: null,
          );
        }
      case 'assistant':
        final textContent = message['content'] as String? ?? '';
        return AiStorageMessage(
          messageType: MessageType.aiResponse,
          message: textContent,
          imageUrl: null,
        );
      default:
        _logger.e('Unknown message role: ${message['role']}');
        throw Exception('Unknown message role');
    }
  }

  Future<void> clearConversationHistory(String chatId) async {
    if (_userDocumentRef == null) throw Exception("Service not initialized.");
    try {
      _logger.i('Clearing conversation history for chat $chatId');
      final messagesCol = _messagesCollectionForChat(chatId);
      final querySnapshot = await messagesCol.get();
      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      await _chatDocumentRef(chatId)
          .update({'lastModifiedAt': FieldValue.serverTimestamp()});
      _logger.i('Conversation history cleared for chat $chatId');
    } catch (e) {
      _logger.e('Failed to clear conversation history for chat $chatId: $e');
      rethrow;
    }
  }

  List<ChatCompletionMessage> convertMessagesToOpenAIFormat(
      List<Map<String, dynamic>> messages) {
    final List<ChatCompletionMessage> chatMessages = [];
    for (var message in messages) {
      final role = message['role'] as String;
      final content = message['content'];

      switch (role) {
        case 'user':
          if (content is List) {
            final List<ChatCompletionMessageContentPart> contentParts = [];
            for (var contentItem in content) {
              if (contentItem['type'] == 'text') {
                contentParts.add(
                  ChatCompletionMessageContentPart.text(
                      text: contentItem['text'] as String? ?? ''),
                );
              } else if (contentItem['type'] == 'image_url') {
                contentParts.add(
                  ChatCompletionMessageContentPart.image(
                    imageUrl: ChatCompletionMessageImageUrl(
                        url: contentItem['image_url']['url'] as String),
                  ),
                );
              }
            }
            chatMessages.add(
              ChatCompletionMessage.user(
                  content:
                      ChatCompletionUserMessageContent.parts(contentParts)),
            );
          } else if (content is String) {
            chatMessages.add(
              ChatCompletionMessage.user(
                  content: ChatCompletionUserMessageContent.string(content)),
            );
          } else {
            _logger.w('User message content is not a List or String: $content');
          }
          break;
        case 'assistant':
          if (content is String) {
            chatMessages.add(ChatCompletionMessage.assistant(content: content));
          } else {
            _logger.w('Assistant message content is not a String: $content');
            chatMessages.add(ChatCompletionMessage.assistant(content: ''));
          }
          break;
        default:
          _logger.e('Unknown message role during OpenAI conversion: $role');
      }
    }
    return chatMessages;
  }

  Future<ChatMetadata?> getChatMetadata(String chatId) async {
    if (_userDocumentRef == null) throw Exception("Service not initialized.");
    try {
      final docSnapshot = await _chatDocumentRef(chatId).get()
          as DocumentSnapshot<Map<String, dynamic>>;
      if (docSnapshot.exists) {
        return ChatMetadata.fromFirestore(docSnapshot);
      }
      return null;
    } catch (e) {
      _logger.e("Error fetching chat metadata for $chatId: $e");
      return null;
    }
  }

  Stream<CreateChatCompletionStreamResponse> getCompletionStream(
      String chatId, List<Map<String, dynamic>> messagesHistory) async* {
    if (_userDocumentRef == null) throw Exception("Service not initialized.");
    _logger.i('Starting streaming request to OpenAI API for chat $chatId');

    final chatMeta = await getChatMetadata(chatId);
    final modelId = chatMeta?.modelId ?? 'gpt-4o-mini';

    final List<ChatCompletionMessage> chatMessages =
        convertMessagesToOpenAIFormat(messagesHistory);

    if (chatMessages.isEmpty && messagesHistory.isNotEmpty) {
      _logger.w(
          "Conversion to OpenAI format resulted in empty messages, but history was not empty. Check conversion logic.");
      return;
    }
    if (chatMessages.isEmpty && messagesHistory.isEmpty) {
      _logger.i("Message history is empty, not sending request to OpenAI.");
      return;
    }

    final stream = client.createChatCompletionStream(
      request: CreateChatCompletionRequest(
        model: ChatCompletionModel.modelId(modelId),
        messages: chatMessages,
      ),
    );
    yield* stream;
  }

  Future<void> updateAndCheckTokenUsage(Usage tokenUsage) async {
    if (_userDocumentRef == null || _tokenUsageSummaryDoc == null) {
      _logger.e("Service not initialized for token updates.");
      return;
    }
    try {
      _logger.i('Updating token logs');
      final today = DateTime.now();
      final dateString =
          "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
      final dailyLogDocRef =
          _tokenUsageSummaryDoc!.collection('daily_logs').doc(dateString);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot dailySnapshot = await transaction.get(dailyLogDocRef);
        Usage currentDailyUsage =
            dailySnapshot.exists && dailySnapshot.data() != null
                ? Usage.fromJson(dailySnapshot.data()! as Map<String, dynamic>)
                : Usage(0, 0, 0);

        final updatedDailyUsage = Usage(
          (currentDailyUsage.promptTokens ?? 0) +
              (tokenUsage.promptTokens ?? 0),
          (currentDailyUsage.completionTokens ?? 0) +
              (tokenUsage.completionTokens ?? 0),
          (currentDailyUsage.totalTokens ?? 0) + (tokenUsage.totalTokens ?? 0),
        );
        transaction.set(dailyLogDocRef, updatedDailyUsage.toJson());

        if (_tokenLimit == 0) {
          _tokenLimitExceeded = false;
        } else if (updatedDailyUsage.totalTokens! > _tokenLimit) {
          _tokenLimitExceeded = true;
        } else {
          _tokenLimitExceeded = false;
        }
      });
      _logger.i('Token usage updated. Exceeded: $_tokenLimitExceeded');
    } catch (e) {
      _logger.e('Failed to update token logs: $e');
    }
  }

  Future<void> checkTokenUsage() async {
    if (_userDocumentRef == null || _tokenUsageSummaryDoc == null) {
      _logger.e("Service not initialized for checking token usage.");
      return;
    }
    try {
      final today = DateTime.now();
      final dateString =
          "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
      final dailyLogDoc = await _tokenUsageSummaryDoc!
          .collection('daily_logs')
          .doc(dateString)
          .get();

      if (dailyLogDoc.exists && dailyLogDoc.data() != null) {
        final dailyUsageData = Usage.fromJson(dailyLogDoc.data()!);
        if (_tokenLimit == 0) {
          _tokenLimitExceeded = false;
        } else if ((dailyUsageData.totalTokens ?? 0) > _tokenLimit) {
          _tokenLimitExceeded = true;
        } else {
          _tokenLimitExceeded = false;
        }
      } else {
        _tokenLimitExceeded = false;
      }
      _logger.i('Token usage check. Exceeded: $_tokenLimitExceeded');
    } catch (e) {
      _logger.e('Failed to check token usage: $e');
    }
  }

  Future<int> getTokensUsedToday() async {
    if (_userDocumentRef == null || _tokenUsageSummaryDoc == null) {
      _logger.e("Service not initialized for getting tokens used today.");
      return 0;
    }
    try {
      final today = DateTime.now();
      final dateString =
          "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
      final dailyLogDoc = await _tokenUsageSummaryDoc!
          .collection('daily_logs')
          .doc(dateString)
          .get();

      if (dailyLogDoc.exists && dailyLogDoc.data() != null) {
        final dailyUsageData = Usage.fromJson(dailyLogDoc.data()!);
        return dailyUsageData.totalTokens ?? 0;
      } else {
        return 0;
      }
    } catch (e) {
      _logger.e('Failed to get tokens used today: $e');
      return 0;
    }
  }

  int getTokenLimit() {
    return _tokenLimit;
  }

  Future<String> createNewChat(
      {required String title, required String modelId}) async {
    if (_userDocumentRef == null) throw Exception("Service not initialized.");
    try {
      _logger.i("Creating new chat with title: '$title', model: '$modelId'");
      final newChatRef = _userDocumentRef!.collection('openai_chats').doc();
      await newChatRef.set({
        'title': title,
        'createdAt': FieldValue.serverTimestamp(),
        'lastModifiedAt': FieldValue.serverTimestamp(),
        'model_id': modelId,
      });
      _logger.i("New chat created with ID: ${newChatRef.id}");
      return newChatRef.id;
    } catch (e) {
      _logger.e("Failed to create new chat: $e");
      rethrow;
    }
  }

  Future<List<ChatMetadata>> listUserChats() async {
    if (_userDocumentRef == null) throw Exception("Service not initialized.");
    try {
      _logger.i("Listing user chats");
      final querySnapshot = await _userDocumentRef!
          .collection('openai_chats')
          .orderBy('lastModifiedAt', descending: true)
          .get();

      final chats = querySnapshot.docs
          .map((doc) => ChatMetadata.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList();
      _logger.i("Found ${chats.length} chats");
      return chats;
    } catch (e) {
      _logger.e("Failed to list user chats: $e");
      rethrow;
    }
  }

  Future<void> updateChatTitle(String chatId, String newTitle) async {
    if (_userDocumentRef == null) throw Exception("Service not initialized.");
    try {
      _logger.i("Updating title for chat $chatId to '$newTitle'");
      await _chatDocumentRef(chatId).update({
        'title': newTitle,
        'lastModifiedAt':
            FieldValue.serverTimestamp(), // Also update last modified
      });
      _logger.i("Chat title updated for $chatId");
    } catch (e) {
      _logger.e("Failed to update chat title for $chatId: $e");
      rethrow;
    }
  }

  Future<void> generateAndSaveChatTitle(
      String chatId, List<Map<String, dynamic>> conversationSample) async {
    if (conversationSample.isEmpty) {
      _logger.i(
          "Conversation sample is empty, cannot generate title for chat $chatId.");
      return;
    }
    if (_userDocumentRef == null) throw Exception("Service not initialized.");

    _logger.i("Generating title for chat $chatId...");

    String promptContent =
        "Summarize the following conversation with a short, descriptive title (5 words or less). Title only, no preamble.\n\n";
    for (var message in conversationSample) {
      String role = message['role'] == 'user' ? 'User' : 'Assistant';
      String textContent = "";
      if (message['content'] is String) {
        textContent = message['content'];
      } else if (message['content'] is List) {
        // Extract text part from list for multimodal messages
        var textPart = (message['content'] as List)
            .firstWhere((part) => part['type'] == 'text', orElse: () => null);
        if (textPart != null) {
          textContent = textPart['text'] ?? '';
        }
      }
      promptContent += "$role: ${textContent.trim()}\n";
    }
    promptContent += "\nTitle:";

    try {
      final request = CreateChatCompletionRequest(
        model: ChatCompletionModel.modelId(
            'gpt-3.5-turbo'), // Use a fast and cheap model for titles
        messages: [
          ChatCompletionMessage.user(
              content: ChatCompletionUserMessageContent.string(promptContent))
        ],
        maxTokens: 15, // Limit tokens for the title
        temperature: 0.3, // Lower temperature for more deterministic titles
      );
      final response = await client.createChatCompletion(request: request);

      if (response.choices.isNotEmpty &&
          response.choices.first.message.content != null) {
        String generatedTitle = response.choices.first.message.content!.trim();
        // Basic cleanup: remove quotes if any, ensure it's not empty
        generatedTitle = generatedTitle.replaceAll('"', '').replaceAll("'", "");
        if (generatedTitle.toLowerCase().startsWith("title:")) {
          generatedTitle = generatedTitle.substring("title:".length).trim();
        }
        if (generatedTitle.isNotEmpty) {
          _logger.i("Generated title for chat $chatId: '$generatedTitle'");
          await updateChatTitle(chatId, generatedTitle);
        } else {
          _logger.w("Generated title was empty for chat $chatId.");
        }
      } else {
        _logger
            .w("Could not generate title for chat $chatId from API response.");
      }
    } catch (e) {
      _logger.e("Error generating chat title for $chatId: $e");
      // Don't rethrow, allow chat to continue with default title
    }
  }

  Future<void> deleteChat(String chatId) async {
    if (_userDocumentRef == null) throw Exception("Service not initialized.");
    try {
      _logger.i("Deleting chat $chatId");
      final messagesCol = _messagesCollectionForChat(chatId);
      final messagesSnapshot = await messagesCol.limit(500).get();
      WriteBatch batch = FirebaseFirestore.instance.batch();
      if (messagesSnapshot.docs.isNotEmpty) {
        for (var doc in messagesSnapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        if (messagesSnapshot.docs.length == 500) {
          _logger.w(
              "Chat $chatId had many messages, more might need deletion if over 500.");
        }
      }
      await _chatDocumentRef(chatId).delete();
      _logger.i("Chat $chatId deleted");
    } catch (e) {
      _logger.e("Failed to delete chat $chatId: $e");
      rethrow;
    }
  }
}
