import 'dart:async';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/gestures.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:studybeats/api/analytics/analytics_service.dart';
import 'package:studybeats/api/auth/auth_service.dart';
import 'package:studybeats/api/openai/openai_service.dart';
import 'package:studybeats/api/stripe/subscription_service.dart';
import 'package:studybeats/log_printer.dart';
import 'package:studybeats/router.dart';
import 'package:studybeats/studyroom/control_bar.dart';
import 'package:studybeats/studyroom/study_tools/aichat/aimessage.dart';
import 'package:studybeats/theme_provider.dart';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker_web/image_picker_web.dart';
import 'package:uuid/uuid.dart';

class PopupMenuDetails extends StatelessWidget {
  final IconData icon;
  final String text;
  const PopupMenuDetails({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Row(
      children: [
        Icon(icon, color: themeProvider.popupMenuIconColor),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: themeProvider.popupMenuIconColor)),
      ],
    );
  }
}

class AiChat extends StatefulWidget {
  const AiChat(
      {required this.onClose, required this.onUpgradePressed, super.key});

  final VoidCallback onClose;
  final VoidCallback onUpgradePressed;

  @override
  State<AiChat> createState() => _AiChatState();
}

class _AiChatState extends State<AiChat> {
  bool _dismissedAnonWarning = false;
  final FocusNode _keyboardListenerFocusNode = FocusNode();
  final FocusNode _textInputFocusNode = FocusNode();
  final TextEditingController _textEditingController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final AuthService _authService = AuthService();
  final OpenaiService _openaiService = OpenaiService();
  final StripeSubscriptionService _subscriptionService =
      StripeSubscriptionService();
  bool _isPasting = false;
  bool _showScrollToBottomButton = false;
  bool _loadingResponse = false;
  bool _loadingImage = false;
  bool _showError = false;
  String? _profilePictureUrl;
  Uint8List? _imageFile;
  String? _imageUrl;
  String _errorMessage = '';
  bool _showTokenMessage = false;
  final double _maxWidth = 1200;
  final double _minWidth = 300;
  double _currentWidth = 400;
  final List<Map<String, dynamic>> _conversationHistory = [];
  int numCharacters = 0;
  bool _isAnonymous = false;
  bool _isPro = false;
  final int _freeChatLimit = 1;
  final _logger = getLogger('AiChat');
  final _analyticsService = AnalyticsService();
  String? _currentChatId;
  ChatMetadata? _currentChatMetadata;
  List<ChatMetadata> _userChats = [];
  bool _isLoadingChats = true;
  bool _isLoadingMessages = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _init();
  }

  Future<void> _init() async {
    try {
      final user = await _authService.getCurrentUser();
      _isAnonymous = user.isAnonymous;

      if (!_isAnonymous) {
        final isPro = await _subscriptionService.hasProMembership();
        if (mounted) {
          setState(() {
            _isPro = isPro;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isPro = false;
          });
        }
      }

      await _openaiService.init();
      await _analyticsService.logOpenFeature(ContentType.aiChat, 'AiChat');
      final url = await _authService.getProfilePictureUrl();
      if (mounted) {
        setState(() => _profilePictureUrl = url);
      }
      await _loadUserChats();
      await _checkAndUpdateTokenStatus();
    } catch (e) {
      _logger.e("Initialization failed: $e");
      if (mounted) {
        setState(() {
          _showError = true;
          _errorMessage = "Failed to initialize chat.";
          _isLoadingChats = false;
        });
      }
    }
  }

  Future<void> _checkAndUpdateTokenStatus() async {
    if (!_openaiService.tokenLimitExceeded) {
      await _openaiService.checkTokenUsage();
    }
    if (mounted) {
      setState(() => _showTokenMessage = _openaiService.tokenLimitExceeded);
    }
  }

  Future<void> _loadUserChats({String? newlySelectedChatId}) async {
    if (!mounted) return;
    setState(() {
      _isLoadingChats = true;
      _showError = false;
    });
    try {
      final chats = await _openaiService.listUserChats();
      if (mounted) {
        setState(() {
          _userChats = chats;
          _isLoadingChats = false;
          String? targetChatId = newlySelectedChatId ?? _currentChatId;

          ChatMetadata? chatToSelect;
          if (targetChatId != null) {
            chatToSelect = _userChats.firstWhere(
                (chat) => chat.id == targetChatId,
                orElse: () => _userChats.isNotEmpty
                    ? _userChats.first
                    : null as ChatMetadata);
          } else if (_userChats.isNotEmpty) {
            chatToSelect = _userChats.first;
          }

          if (chatToSelect != null) {
            _selectChat(chatToSelect);
          } else {
            _currentChatId = null;
            _currentChatMetadata = null;
            _conversationHistory.clear();
            _isLoadingMessages = false;
          }
        });
      }
    } catch (e) {
      _logger.e('Failed to load user chats: $e');
      if (mounted) {
        setState(() {
          _isLoadingChats = false;
          _showError = true;
          _errorMessage = 'Failed to load chats.';
        });
      }
    }
  }

  Future<void> _selectChat(ChatMetadata? chatMetadata,
      {bool userInitiated = false}) async {
    if (!mounted) return;

    final bool shouldCloseDrawer =
        userInitiated && (_scaffoldKey.currentState?.isDrawerOpen ?? false);

    if (chatMetadata == null) {
      if (mounted) {
        setState(() {
          _currentChatId = null;
          _currentChatMetadata = null;
          _conversationHistory.clear();
          _isLoadingMessages = false;
          _textEditingController.clear();
          numCharacters = 0;
        });
      }
      _logger.i("No chat selected or available.");
      if (shouldCloseDrawer) {
        Navigator.of(context).pop();
      }
      return;
    }

    if (_currentChatId == chatMetadata.id &&
        _conversationHistory.isNotEmpty &&
        !_isLoadingMessages) {
      _logger.i("Chat ${chatMetadata.id} already selected.");
      if (mounted) {
        setState(() => _currentChatMetadata = chatMetadata);
      }
      if (shouldCloseDrawer) {
        Navigator.of(context).pop();
      }
      return;
    }

    setState(() {
      _currentChatId = chatMetadata.id;
      _currentChatMetadata = chatMetadata;
      _conversationHistory.clear();
      _isLoadingMessages = true;
      _showError = false;
      _textEditingController.clear();
      numCharacters = 0;
    });

    _logger.i("Selected chat: ${chatMetadata.title} (ID: ${chatMetadata.id})");
    if (shouldCloseDrawer) {
      Navigator.of(context).pop();
    }

    try {
      final history =
          await _openaiService.getConversationHistory(_currentChatId!);
      if (mounted) {
        setState(() {
          _conversationHistory.addAll(history);
          _isLoadingMessages = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      _logger.e('Failed to load messages for chat $_currentChatId: $e');
      if (mounted) {
        setState(() {
          _isLoadingMessages = false;
          _showError = true;
          _errorMessage = 'Failed to load messages.';
        });
      }
    }
    await _checkAndUpdateTokenStatus();
  }

  Future<void> _handleCreateNewChat() async {
    if (!_isPro && _userChats.length >= _freeChatLimit) {
      _logger.w(
          "Chat limit reached. Pro: $_isPro, Anon: $_isAnonymous. Prompting for action.");
      widget.onUpgradePressed();
      return;
    }

    final defaultModelId = "gpt-4o-mini";
    final newChatTitle =
        "New Chat ${DateFormat('MMM d, HH:mm').format(DateTime.now())}";
    try {
      final newChatId = await _openaiService.createNewChat(
          title: newChatTitle, modelId: defaultModelId);
      await _loadUserChats(newlySelectedChatId: newChatId);
    } catch (e) {
      _logger.e('Failed to create new chat: $e');
      if (mounted) {
        setState(() {
          _showError = true;
          _errorMessage = 'Could not create new chat.';
        });
      }
    }
  }

  void _scrollListener() {
    if (!mounted || !_scrollController.hasClients) return;
    setState(() {
      _showScrollToBottomButton = _scrollController.position.pixels <
          _scrollController.position.maxScrollExtent - 50;
    });
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _keyboardListenerFocusNode.dispose();
    _textInputFocusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients &&
          _scrollController.position.hasContentDimensions) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.fastLinearToSlowEaseIn,
        );
      }
    });
  }

  Future<void> _sendMessageAndClearInput({String? textToUse}) async {
    final String currentText = textToUse ?? _textEditingController.text;
    if (currentText.trim().isNotEmpty ||
        _imageFile != null ||
        _imageUrl != null) {
      await _sendMessageLogic(currentText);
      if (mounted) {
        _textEditingController.clear();
        setState(() {
          numCharacters = 0;
        });
      }
    }
  }

  Future<void> _sendMessageLogic(String textForMessage) async {
    if (_currentChatId == null) {
      if (mounted) {
        setState(() {
          _showError = true;
          _errorMessage = "Please select a chat.";
        });
      }
      return;
    }
    if (_loadingResponse || _isLoadingMessages || _loadingImage) return;

    if (textForMessage.trim().isEmpty &&
        _imageFile == null &&
        _imageUrl == null) {
      _logger.w("Send message logic called with no content.");
      return;
    }

    if (_openaiService.tokenLimitExceeded) {
      if (mounted) setState(() => _showTokenMessage = true);
      return;
    }

    setState(() {
      _showError = false;
      _loadingResponse = true;
    });

    int promptTokens = 0;
    Map<String, dynamic> userMessageMap;
    final bool isFirstUserMessageInNewChat =
        _conversationHistory.where((m) => m['role'] == 'user').isEmpty &&
            (_currentChatMetadata?.title.startsWith("New Chat") ?? false);
    String? firstUserMessageContentForTitle;
    final String trimmedTextForMessage = textForMessage.trim();

    try {
      if (_imageUrl != null) {
        userMessageMap = {
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text':
                  trimmedTextForMessage.isEmpty ? ' ' : trimmedTextForMessage
            },
            {
              'type': 'image_url',
              'image_url': {'url': _imageUrl}
            }
          ]
        };
        promptTokens = _openaiService.tokenizer
                .numTokensFromString(trimmedTextForMessage) +
            _openaiService.tokenizer.sizeFromImageUrl(_imageUrl!);
        if (isFirstUserMessageInNewChat) {
          firstUserMessageContentForTitle = trimmedTextForMessage.isEmpty
              ? 'Image analysis'
              : trimmedTextForMessage;
        }
      } else {
        userMessageMap = {'role': 'user', 'content': trimmedTextForMessage};
        promptTokens =
            _openaiService.tokenizer.numTokensFromString(trimmedTextForMessage);
        if (isFirstUserMessageInNewChat) {
          firstUserMessageContentForTitle = trimmedTextForMessage;
        }
      }

      if (mounted) {
        setState(() {
          _conversationHistory.add(userMessageMap);
          _imageFile = null;
        });
      }
      _scrollToBottom();
      await _openaiService.addToConversationHistory(
          _currentChatId!, userMessageMap);
      if (mounted) setState(() => _imageUrl = null);

      final assistantPlaceholder = {'role': 'assistant', 'content': ''};
      if (mounted) {
        setState(() => _conversationHistory.add(assistantPlaceholder));
      }
      _scrollToBottom();

      final stream = _openaiService.getCompletionStream(_currentChatId!,
          _conversationHistory.sublist(0, _conversationHistory.length - 1));
      String fullAssistantResponse = "";
      await for (var response in stream) {
        if (response.choices.isNotEmpty &&
            response.choices.first.delta.content != null) {
          fullAssistantResponse += response.choices.first.delta.content!;
          if (mounted) {
            setState(() =>
                _conversationHistory.last['content'] = fullAssistantResponse);
            _scrollToBottom();
          }
        }
      }

      if (mounted) setState(() => _loadingResponse = false);

      final completionTokens =
          _openaiService.tokenizer.numTokensFromString(fullAssistantResponse);
      final usage = Usage(
          promptTokens, completionTokens, promptTokens + completionTokens);
      await _openaiService.updateAndCheckTokenUsage(usage);
      await _openaiService.addToConversationHistory(_currentChatId!,
          {'role': 'assistant', 'content': fullAssistantResponse});

      if (isFirstUserMessageInNewChat &&
          firstUserMessageContentForTitle != null &&
          fullAssistantResponse.isNotEmpty) {
        final List<Map<String, dynamic>> sample = [
          userMessageMap,
          {'role': 'assistant', 'content': fullAssistantResponse}
        ];
        _openaiService
            .generateAndSaveChatTitle(_currentChatId!, sample)
            .then((_) => _loadUserChats(newlySelectedChatId: _currentChatId))
            .catchError((e) => _logger.e("Error auto-generating title: $e"));
      }
      if (mounted) {
        setState(() => _showTokenMessage = _openaiService.tokenLimitExceeded);
      }
    } catch (e) {
      _logger.e('Error sending message: $e');
      if (mounted) {
        setState(() {
          _loadingResponse = false;
          _showError = true;
          _errorMessage = 'Failed to send message.';
          if (_conversationHistory.isNotEmpty &&
              _conversationHistory.last['role'] == 'assistant' &&
              _conversationHistory.last['content'] == '') {
            _conversationHistory.removeLast();
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingResponse = false;
          _loadingImage = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return SizedBox(
      width: _currentWidth,
      height: MediaQuery.of(context).size.height - kControlBarHeight,
      child: KeyboardListener(
        focusNode: _keyboardListenerFocusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Scaffold(
          key: _scaffoldKey,
          appBar: buildAppBar(themeProvider),
          drawer: _buildChatDrawer(themeProvider),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  themeProvider.appBackgroundGradientStart,
                  themeProvider.appBackgroundGradientEnd
                ],
              ),
            ),
            child: Stack(
              children: [
                Column(
                  children: [
                    if (_isAnonymous && !_dismissedAnonWarning)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 14),
                          decoration: BoxDecoration(
                            color: themeProvider.warningBackgroundColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: themeProvider.warningBorderColor),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  size: 20,
                                  color: themeProvider.warningIconColor),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "Chats are not saved for anonymous users. Sign up to save your history!",
                                  style: GoogleFonts.inter(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                    color: themeProvider.warningTextColor,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.close,
                                    size: 18,
                                    color: themeProvider.warningTextColor),
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  setState(() {
                                    _dismissedAnonWarning = true;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    Expanded(child: _buildMessagesArea(themeProvider)),
                    _showTokenMessage && _currentChatId != null
                        ? Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10.0, vertical: 15.0),
                            child: _getTokenExceededMessage(
                                context, themeProvider),
                          )
                        : (_currentChatId != null
                            ? buildTextInputFields(themeProvider)
                            : const SizedBox.shrink()),
                  ],
                ),
                if (_showScrollToBottomButton && _currentChatId != null)
                  Positioned(
                    bottom: 150,
                    right: 20,
                    child: FloatingActionButton(
                      mini: true,
                      onPressed: _scrollToBottom,
                      backgroundColor: themeProvider.primaryAppColor,
                      child:
                          const Icon(Icons.arrow_downward, color: Colors.white),
                    ),
                  ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      if (!mounted) return;
                      setState(() {
                        _currentWidth += details.primaryDelta!;
                        if (_currentWidth < _minWidth) {
                          _currentWidth = _minWidth;
                        }
                        if (_currentWidth > _maxWidth) {
                          _currentWidth = _maxWidth;
                        }
                      });
                    },
                    child: Container(
                      height: MediaQuery.of(context).size.height,
                      width: 5,
                      color: Colors.transparent,
                      child: const MouseRegion(
                          cursor: SystemMouseCursors.resizeColumn),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessagesArea(ThemeProvider themeProvider) {
    if (_isLoadingChats && _currentChatId == null) {
      return Center(
          child: Shimmer.fromColors(
              baseColor: themeProvider.shimmerBaseColor,
              highlightColor: themeProvider.shimmerHighlightColor,
              child: Container(
                height: MediaQuery.of(context).size.height,
                color: themeProvider.shimmerHighlightColor,
              )));
    }
    if (_currentChatId == null) {
      return Center(
          child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.chat_bubble_outline,
              size: 50, color: themeProvider.secondaryTextColor),
          const SizedBox(height: 10),
          Text(
              _userChats.isEmpty
                  ? "Create a new chat to begin."
                  : "Select a chat from the side menu.",
              style:
                  TextStyle(fontSize: 16, color: themeProvider.mainTextColor),
              textAlign: TextAlign.center),
          if (_userChats.isEmpty) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text("New Chat"),
              onPressed: _handleCreateNewChat,
              style: ElevatedButton.styleFrom(
                  backgroundColor: themeProvider.primaryAppColor,
                  foregroundColor: Colors.white),
            )
          ]
        ]),
      ));
    }
    if (_isLoadingMessages) {
      return Center(
          child: Shimmer.fromColors(
              baseColor: themeProvider.shimmerBaseColor,
              highlightColor: themeProvider.shimmerHighlightColor,
              child: Container(
                height: MediaQuery.of(context).size.height - 269,
                color: themeProvider.shimmerHighlightColor,
              )));
    }
    if (_conversationHistory.isEmpty) {
      return Center(
          child: Text("Send a message to start this chat...",
              style:
                  TextStyle(fontSize: 16, color: themeProvider.mainTextColor)));
    }

    return Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 13, 8),
        child: Scrollbar(
          thumbVisibility: true,
          controller: _scrollController,
          child: ListView.builder(
            controller: _scrollController,
            itemCount: _conversationHistory.length,
            itemBuilder: (context, index) {
              final messageMap = _conversationHistory[index];
              final message = _openaiService.convertMessage(messageMap);
              final isUser =
                  message.messageType == MessageType.userMessageTextOnly ||
                      message.messageType == MessageType.userMessageWithImage;
              return AiMessage(
                isUser: isUser,
                message: message.message,
                profilePictureUrl: _profilePictureUrl,
                imageUrl: message.imageUrl,
                onCopyIconPressed: _copyToClipboard,
                isLoadingResponse: _loadingResponse &&
                    index + 1 == _conversationHistory.length &&
                    !isUser,
              );
            },
          ),
        ));
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (HardwareKeyboard.instance.isShiftPressed) {
        } else {
          final String currentText = _textEditingController.text;
          if (currentText.trim().isNotEmpty ||
              _imageFile != null ||
              _imageUrl != null) {
            _sendMessageAndClearInput(textToUse: currentText);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _textEditingController.clear();
                setState(() => numCharacters = 0);
              }
            });
          }
        }
      } else if (event.logicalKey == LogicalKeyboardKey.control ||
          event.logicalKey == LogicalKeyboardKey.meta) {
        if (mounted) setState(() => _isPasting = true);
      }
    } else if (event is KeyUpEvent &&
        (event.logicalKey == LogicalKeyboardKey.control ||
            event.logicalKey == LogicalKeyboardKey.meta)) {
      if (mounted) setState(() => _isPasting = false);
    }
  }

  AppBar buildAppBar(ThemeProvider themeProvider) {
    return AppBar(
      backgroundColor: themeProvider.appContentBackgroundColor,
      elevation: 1.0,
      iconTheme: IconThemeData(color: themeProvider.iconColor),
      title: Text(
        _currentChatMetadata?.title ?? "AI Chat",
        style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: themeProvider.headerTextColor),
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        Theme(
          data: ThemeData(
              popupMenuTheme: PopupMenuThemeData(
                  color: themeProvider.isDarkMode
                      ? const Color.fromRGBO(57, 57, 57, 1)
                      : Colors.white)),
          child: PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'info') await showInfoDialog(themeProvider);
              if (value == 'clear_chat' && _currentChatId != null) {
                await _showClearCurrentChatDialog(themeProvider);
              }
              if (value == 'delete_chat' && _currentChatId != null) {
                await _showDeleteCurrentChatDialog(themeProvider);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                  value: 'info',
                  child: PopupMenuDetails(
                      icon: Icons.info_outline, text: 'Token Info')),
              if (_currentChatId != null)
                const PopupMenuItem(
                    value: 'clear_chat',
                    child: PopupMenuDetails(
                        icon: Icons.delete_outline_sharp,
                        text: 'Clear Current Chat')),
              if (_currentChatId != null)
                const PopupMenuItem(
                    value: 'delete_chat',
                    child: PopupMenuDetails(
                        icon: Icons.delete_forever_outlined,
                        text: 'Delete Current Chat')),
            ],
            icon: Icon(Icons.more_horiz, color: themeProvider.iconColor),
          ),
        ),
        IconButton(
          onPressed: widget.onClose,
          icon: Icon(Icons.close, color: themeProvider.iconColor),
        ),
      ],
    );
  }

  Widget _buildChatDrawer(ThemeProvider themeProvider) {
    final bool chatLimitReached =
        !_isPro && _userChats.length >= _freeChatLimit;

    return Drawer(
      backgroundColor: themeProvider.appContentBackgroundColor,
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: themeProvider.primaryAppDarkColor),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('Your Chats',
                    style: GoogleFonts.inter(
                        color: themeProvider.drawerHeaderTextColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w600)),
                IconButton(
                    icon: Icon(Icons.add_circle,
                        color: chatLimitReached
                            ? Colors.grey[600]
                            : themeProvider.drawerHeaderTextColor,
                        size: 28),
                    tooltip: chatLimitReached
                        ? (_isAnonymous
                            ? "Sign up to create more chats"
                            : "Upgrade to Pro for unlimited chats")
                        : "Create New Chat",
                    onPressed: () {
                      if (chatLimitReached) {
                        if (_isAnonymous) {
                          context.goNamed(AppRoute.loginPage.name);
                        } else {
                          widget.onUpgradePressed();
                        }
                      } else {
                        _handleCreateNewChat();
                      }
                    })
              ],
            ),
          ),
          Expanded(
            child: _isLoadingChats
                ? Center(
                    child: CircularProgressIndicator(
                        color: themeProvider.primaryAppColor))
                : _userChats.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.forum_outlined,
                                  size: 40,
                                  color: themeProvider.secondaryTextColor),
                              const SizedBox(height: 10),
                              Text(
                                "No chats yet.\nClick '+' above to start a new conversation!",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 16,
                                    color: themeProvider.secondaryTextColor),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _userChats.length,
                        itemBuilder: (context, index) {
                          final chat = _userChats[index];
                          final bool isSelected = chat.id == _currentChatId;
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12.0, vertical: 6.0),
                            child: Material(
                              color: isSelected
                                  ? themeProvider.selectedItemBackgroundColor
                                  : themeProvider.appContentBackgroundColor,
                              borderRadius: BorderRadius.circular(12),
                              elevation: isSelected ? 2 : 0,
                              shadowColor: themeProvider.primaryAppColor
                                  .withOpacity(0.2),
                              child: InkWell(
                                onTap: () =>
                                    _selectChat(chat, userInitiated: true),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12.0, horizontal: 12.0),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.chat_bubble_outline,
                                          color: isSelected
                                              ? themeProvider.drawerIconColor
                                              : themeProvider
                                                  .secondaryTextColor,
                                          size: 22),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(chat.title,
                                                  style: GoogleFonts.inter(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 14,
                                                      color: themeProvider
                                                          .mainTextColor),
                                                  overflow:
                                                      TextOverflow.ellipsis),
                                              const SizedBox(height: 4),
                                              Row(children: [
                                                Text(
                                                    DateFormat('M/d/y h:mm a')
                                                        .format(chat
                                                            .lastModifiedAt
                                                            .toLocal()),
                                                    style: GoogleFonts.inter(
                                                        fontSize: 11,
                                                        color: themeProvider
                                                            .secondaryTextColor)),
                                              ]),
                                            ]),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        separatorBuilder: (context, index) => Divider(
                          height: 0,
                          indent: 16,
                          endIndent: 16,
                          color: themeProvider.dividerColor,
                        ),
                      ),
          ),
          if (!_isPro && !_isAnonymous) _buildDrawerProPromotion(themeProvider),
        ],
      ),
    );
  }

  Widget _buildDrawerProPromotion(ThemeProvider themeProvider) {
    return InkWell(
      onTap: widget.onUpgradePressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        color: themeProvider.isDarkMode
            ? themeProvider.appContentBackgroundColor.withAlpha(200)
            : themeProvider.primaryAppColor.withOpacity(0.05),
        child: Row(
          children: [
            Image.asset(
              'assets/icons/crown.png',
              width: 24,
              height: 24,
              color: Colors.amber[600],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Upgrade to Pro",
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: themeProvider.mainTextColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Unlimited chats, image uploads & more.",
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: themeProvider.secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.keyboard_arrow_right,
                color: themeProvider.secondaryTextColor),
          ],
        ),
      ),
    );
  }

  Widget buildTextInputFields(ThemeProvider themeProvider) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24.0),
            color: themeProvider.appContentBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 0,
                blurRadius: 8,
                offset: const Offset(0, -2),
              )
            ]),
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_imageFile != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: ImagePreviewWidget(
                  imageFile: _imageFile,
                  onDelete: () => setState(() {
                    _imageFile = null;
                    _imageUrl = null;
                  }),
                ),
              ),
            TextField(
              controller: _textEditingController,
              focusNode: _textInputFocusNode,
              cursorColor: themeProvider.primaryAppColor,
              maxLines: 7,
              minLines: 1,
              textInputAction: TextInputAction.newline,
              keyboardType: TextInputType.multiline,
              style: GoogleFonts.inter(
                  fontSize: 15, color: themeProvider.mainTextColor),
              decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: GoogleFonts.inter(
                      color: themeProvider.secondaryTextColor),
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 4)),
              inputFormatters: [LengthLimitingTextInputFormatter(2000)],
              onChanged: (text) => setState(() => numCharacters = text.length),
              onSubmitted: (String text) {
                if (!HardwareKeyboard.instance.isShiftPressed) {
                  _sendMessageAndClearInput(textToUse: text);
                }
              },
            ),
            Divider(
              height: 1,
              thickness: 0.5,
              color: themeProvider.dividerColor,
            ),
            Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.add_photo_alternate_outlined,
                          color: (_loadingImage || !_isPro)
                              ? Colors.grey
                              : themeProvider.primaryAppColor.withOpacity(0.8)),
                      tooltip: _isPro
                          ? "Attach Image"
                          : _isAnonymous
                              ? "Sign up to attach images"
                              : "Attach Image (Pro feature)",
                      onPressed: _loadingImage
                          ? null
                          : (_isPro
                              ? _pickImage
                              : () {
                                  if (_isAnonymous) {
                                    context.goNamed(AppRoute.loginPage.name);
                                  } else {
                                    widget.onUpgradePressed();
                                  }
                                }),
                    ),
                    if (!_isPro && !_isAnonymous)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: GestureDetector(
                          onTap: widget.onUpgradePressed,
                          child: Container(
                            padding: const EdgeInsets.all(1.5),
                            decoration: BoxDecoration(
                              color: Colors.amber[600],
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color:
                                      themeProvider.appContentBackgroundColor,
                                  width: 1),
                            ),
                            child: Image.asset(
                              'assets/icons/crown.png',
                              width: 8,
                              height: 8,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Text('$numCharacters/2000',
                    style: TextStyle(
                        fontSize: 11, color: themeProvider.secondaryTextColor)),
                const SizedBox(width: 8.0),
                IconButton(
                  icon: Icon(Icons.send_rounded,
                      color: (_loadingResponse ||
                              _loadingImage ||
                              (_textEditingController.text.trim().isEmpty &&
                                  _imageFile == null &&
                                  _imageUrl == null))
                          ? themeProvider.secondaryTextColor
                          : themeProvider.primaryAppColor),
                  tooltip: "Send Message",
                  onPressed: (_loadingResponse ||
                          _loadingImage ||
                          (_textEditingController.text.trim().isEmpty &&
                              _imageFile == null &&
                              _imageUrl == null))
                      ? null
                      : () => _sendMessageAndClearInput(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showClearCurrentChatDialog(ThemeProvider themeProvider) async {
    if (_currentChatId == null) return;
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
                backgroundColor: themeProvider.popupBackgroundColor,
                title: Text('Clear messages in this chat?',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: themeProvider.mainTextColor)),
                content: Text(
                    'This will delete all messages in the current chat. This action cannot be undone.',
                    style: GoogleFonts.inter(
                        color: themeProvider.mainTextColor.withOpacity(0.8))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Cancel',
                          style: TextStyle(
                              color: themeProvider.secondaryTextColor))),
                  TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _clearCurrentChatMessages();
                      },
                      child: Text('Clear Messages',
                          style: TextStyle(color: Colors.orange[700])))
                ]));
  }

  Future<void> _showDeleteCurrentChatDialog(ThemeProvider themeProvider) async {
    if (_currentChatId == null || _currentChatMetadata == null) return;
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
                backgroundColor: themeProvider.popupBackgroundColor,
                title: Text('Delete "${_currentChatMetadata!.title}"?',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: themeProvider.mainTextColor)),
                content: Text(
                    'This will permanently delete this chat and all its messages. This action cannot be undone.',
                    style: GoogleFonts.inter(
                        color: themeProvider.mainTextColor.withOpacity(0.8))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Cancel',
                          style: TextStyle(
                              color: themeProvider.secondaryTextColor))),
                  TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _deleteCurrentChat();
                      },
                      child: Text('Delete Chat',
                          style: TextStyle(color: Colors.red[700])))
                ]));
  }

  Future<void> _clearCurrentChatMessages() async {
    if (_currentChatId == null) return;
    try {
      await _openaiService.clearConversationHistory(_currentChatId!);
      if (mounted) setState(() => _conversationHistory.clear());
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Chat messages cleared.'),
          behavior: SnackBarBehavior.floating));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Error clearing messages.'),
          behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _deleteCurrentChat() async {
    if (_currentChatId == null) return;
    String? chatToDeleteId = _currentChatId;
    try {
      await _openaiService.deleteChat(chatToDeleteId!);
      await _loadUserChats();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Chat deleted.'), behavior: SnackBarBehavior.floating));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Error deleting chat.'),
          behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> showInfoDialog(ThemeProvider themeProvider) async {
    int tokensUsedToday = await _openaiService.getTokensUsedToday();
    final int tokenLimit = _openaiService.getTokenLimit();
    if (tokensUsedToday > tokenLimit && tokenLimit != 0) {
      tokensUsedToday = tokenLimit;
    }
    String tokensUsedTodayStr =
        NumberFormat.decimalPattern().format(tokensUsedToday);
    String tokenLimitStr = tokenLimit == 0
        ? "∞"
        : NumberFormat.decimalPattern().format(tokenLimit);

    if (mounted) {
      showDialog(
          context: context,
          builder: (context) => AlertDialog(
                  backgroundColor: themeProvider.popupBackgroundColor,
                  title: Row(children: [
                    Text('Token Details',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: themeProvider.mainTextColor)),
                    const Spacer(),
                    IconButton(
                        icon: Icon(Icons.close,
                            color: themeProvider.mainTextColor),
                        onPressed: () => Navigator.of(context).pop())
                  ]),
                  content: SizedBox(
                      height: 80,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'Tokens used today: $tokensUsedTodayStr / $tokenLimitStr',
                                style: GoogleFonts.inter(
                                    color: themeProvider.mainTextColor
                                        .withOpacity(0.9))),
                            const SizedBox(height: 20),
                            if (tokenLimit != 0)
                              LinearProgressIndicator(
                                value: tokensUsedToday / tokenLimit,
                                backgroundColor: Colors.grey[300],
                                valueColor: AlwaysStoppedAnimation(
                                    themeProvider.primaryAppColor),
                                minHeight: 10,
                                borderRadius: BorderRadius.circular(5),
                              )
                            else
                              Text("You have unlimited tokens.",
                                  style: GoogleFonts.inter(
                                      color: themeProvider.mainTextColor
                                          .withOpacity(0.9))),
                          ])),
                  actions: [
                    ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onUpgradePressed();
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: themeProvider.primaryAppColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8))),
                        child: Text('Get more tokens',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600))),
                    OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                            side: BorderSide(
                                color: themeProvider.secondaryTextColor),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8))),
                        child: Text('Close',
                            style: GoogleFonts.inter(
                                color: themeProvider.mainTextColor)))
                  ]));
    }
  }

  Widget _getTokenExceededMessage(
      BuildContext context, ThemeProvider themeProvider) {
    return RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
            style: TextStyle(
                color: themeProvider.secondaryTextColor, fontSize: 12),
            children: [
              const TextSpan(text: 'Token limit reached for today. '),
              TextSpan(
                  text: 'Upgrade',
                  style: TextStyle(
                      color: themeProvider.primaryAppColor,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => widget.onUpgradePressed()),
              const TextSpan(text: ' or wait.')
            ]));
  }

  Future<void> _pickImage() async {
    if (!_isPro) {
      widget.onUpgradePressed();
      return;
    }
    if (!mounted) return;
    setState(() {
      _imageFile = null;
      _imageUrl = null;
      _loadingImage = true;
    });
    try {
      final file = await ImagePickerWeb.getImageAsFile();
      if (file == null) {
        if (mounted) setState(() => _loadingImage = false);
        return;
      }
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      await reader.onLoadEnd.first;
      if (mounted) setState(() => _imageFile = reader.result as Uint8List);

      final filename = const Uuid().v4();
      final ref =
          FirebaseStorage.instance.ref().child('openai_user_images/$filename');
      await ref.putBlob(file);
      final downloadUrl = await ref.getDownloadURL();
      if (mounted) {
        setState(() {
          _imageUrl = downloadUrl;
          _loadingImage = false;
        });
      }
    } catch (e) {
      _logger.e("Error picking image: $e");
      if (mounted) {
        setState(() {
          _loadingImage = false;
          _showError = true;
          _errorMessage = "Failed to process image.";
        });
      }
    }
  }
}

class ImagePreviewWidget extends StatefulWidget {
  const ImagePreviewWidget(
      {super.key, required this.imageFile, required this.onDelete});
  final Uint8List? imageFile;
  final VoidCallback onDelete;
  @override
  State<ImagePreviewWidget> createState() => _ImagePreviewWidgetState();
}

class _ImagePreviewWidgetState extends State<ImagePreviewWidget> {
  bool _isHovering = false;
  @override
  Widget build(BuildContext context) {
    if (widget.imageFile == null) return const SizedBox.shrink();
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Stack(alignment: Alignment.topRight, children: [
            Container(
                height: 100,
                width: 100,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                        fit: BoxFit.cover,
                        image: MemoryImage(widget.imageFile!)))),
            if (_isHovering)
              InkWell(
                  onTap: widget.onDelete,
                  child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 18))),
          ])),
    );
  }
}
