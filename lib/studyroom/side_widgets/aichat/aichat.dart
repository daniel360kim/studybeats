import 'dart:ui';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/gestures.dart';
import 'package:studybeats/api/analytics/analytics_service.dart';
import 'package:studybeats/api/openai/openai_service.dart';
import 'package:studybeats/log_printer.dart';
import 'package:studybeats/studyroom/side_widgets/aichat/aimessage.dart';
import 'package:studybeats/studyroom/audio_widgets/screens/queue.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:studybeats/studyroom/side_widgets/aichat/tokenizer.dart';
import 'package:universal_html/html.dart' as html;
import 'package:studybeats/api/auth/auth_service.dart';
import 'package:studybeats/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker_web/image_picker_web.dart';
import 'package:uuid/uuid.dart';

class ConversationMessage {
  final String message;
  final Uint8List? imageFile;

  const ConversationMessage({required this.message, this.imageFile});
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
  final FocusNode _keyboardListenerFocusNode = FocusNode();
  final FocusNode _textInputFocusNode = FocusNode();
  final TextEditingController _textEditingController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final AuthService _authService = AuthService();

  bool _isPasting = false;
  bool _showScrollToBottomButton = false;
  bool _loadingResponse = false;
  bool _loadingConversationHistory = true;
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

  final _logger = getLogger('AiChat');
  final _analyticsService = AnalyticsService();

  final OpenaiService _openaiService = OpenaiService();
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _init();
  }

  void _init() async {
    await _openaiService.init();
    await _openaiService.checkTokenUsage();
    await _analyticsService.logOpenFeature(ContentType.aiChat, 'AiChat');
    final url = await _authService.getProfilePictureUrl();
    // Get conversation history from Firestore
    try {
      final conversationHistory = await _openaiService.getConversationHistory();
      if (mounted) {
        setState(() {
          _profilePictureUrl = url;
          _conversationHistory.addAll(conversationHistory);
          _loadingConversationHistory = false;
        });
      }
      _scrollToBottom();
      if (mounted) {
        setState(() {
          _showTokenMessage = _openaiService.tokenLimitExceeded;
        });
      }
    } catch (e) {
      _logger.e('Failed to get conversation history from Firestore: $e');
      if (mounted) {
        setState(() {
          _showError = true;
          _errorMessage = 'Failed to get conversation history';
        });
      }
      return;
    }
  }

  void _scrollListener() {
    setState(() {
      _showScrollToBottomButton = _scrollController.position.pixels <
          _scrollController.position.maxScrollExtent;
    });
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.fastLinearToSlowEaseIn,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_loadingResponse || _loadingConversationHistory || _loadingImage) {
      return;
    }

    if ([_textEditingController.text, _imageFile, _imageUrl]
        .every((element) => element == null)) {
      _logger.w('No message to send');
      return;
    }

    setState(() {
      _showError = false;
    });
    int promptTokens = 0;
    try {
      late final String? text;
      if (_textEditingController.text.isNotEmpty) {
        text = _textEditingController.text;
      } else {
        text = null;
      }

      _textEditingController.clear();
      _scrollToBottom();

      setState(() {
        numCharacters = 0;
        _loadingResponse = true;
        _loadingImage = true;
      });

      if (_imageUrl != null) {
        promptTokens = Tokenizer().numTokensFromString(text) +
            Tokenizer().sizeFromImageUrl(_imageUrl!);
        Map<String, dynamic> message = {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': text ?? ''},
            {
              'type': 'image_url',
              'image_url': {'url': _imageUrl}
            }
          ]
        };

        await _openaiService.addToConversationHistory(message);

        setState(() {
          _conversationHistory.add(message);
          _imageFile = null;
          _imageUrl = null;
        });
        _scrollToBottom();
      } else {
        promptTokens = Tokenizer().numTokensFromString(text);
        Map<String, dynamic> message = {
          'role': 'user',
          'content': text,
        };
        setState(() {
          _conversationHistory.add(message);
        });
        await _openaiService.addToConversationHistory(message);

        setState(() {
          _showTokenMessage = _openaiService.tokenLimitExceeded;
        });

        _scrollToBottom();
      }
    } catch (e) {
      _logger.e('Failed to store message in Firestore: $e');
      setState(() {
        _loadingResponse = false;
        _showError = true;
        _errorMessage = 'Failed to store message';
        _conversationHistory.removeLast(); // Remove the placeholder message
      });
    }
    try {
      // Add a placeholder for the assistant's response, so the user can see that a response is incoming
      setState(() {
        _conversationHistory.add({
          'role': 'assistant',
          'content': '',
        });
      });

      final stream = _openaiService.getCompletionStream(_conversationHistory);

      stream.listen(
        onError: (error) {
          setState(() {
            _logger.e('Failed to get response from API: $error');
            _loadingResponse = false;
            _showError = true;
            _errorMessage = 'Failed to get response';
          });
        },
        (response) {
          setState(() {
            _conversationHistory.last['content'] +=
                response.choices.first.delta.content;
          });
        },
        onDone: () async {
          try {
            final completionTokens = Tokenizer()
                .numTokensFromString(_conversationHistory.last['content']);
            final usage = Usage(promptTokens, completionTokens,
                promptTokens + completionTokens);

            await _openaiService.updateAndCheckTokenUsage(usage);
            Map<String, dynamic> message = {
              'role': 'assistant',
              'content': _conversationHistory.last['content'],
            };
            await _openaiService.addToConversationHistory(message);

            setState(() {
              numCharacters = 0;
              _conversationHistory.last = message;
              _loadingImage = false;
              _loadingResponse = false;
            });
          } catch (e) {
            _logger.e('Failed to store message in Firestore: $e');
            setState(() {
              _loadingResponse = false;
              _showError = true;
              _errorMessage = 'Failed to store message';
              _conversationHistory
                  .removeLast(); // Remove the placeholder message
            });
          }
        },
      );

      _scrollToBottom();
    } catch (e) {
      _logger.e('Failed to get response from API: $e');
      setState(() {
        _conversationHistory.removeLast(); // Remove the placeholder message
        _loadingResponse = false;
        _showError = true;
        _errorMessage = 'Failed to get response';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _currentWidth,
      height: MediaQuery.of(context).size.height - 80,
      child: KeyboardListener(
        focusNode: _keyboardListenerFocusNode,
        onKeyEvent: _handleKeyEvent,
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Color(0xFFE0E7FF),
                    Color(0xFFF7F8FC),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Column(
                    children: [
                      buildTopBar(),
                      _loadingConversationHistory
                          ? Shimmer.fromColors(
                              baseColor: Colors.grey[300]!,
                              highlightColor: Colors.grey[100]!,
                              child: Container(
                                height:
                                    MediaQuery.of(context).size.height - 269,
                                color: Colors.white,
                              ),
                            )
                          : Expanded(
                              // Padding keeps resize tab from covering scroll input
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(0, 0, 5, 0),
                                child: ListView.builder(
                                  cacheExtent: 100000,
                                  controller: _scrollController,
                                  itemCount: _conversationHistory.length,
                                  itemBuilder: (context, index) {
                                    final message = OpenaiService()
                                        .convertMessage(
                                            _conversationHistory[index]);
                                    final isUser = message.messageType ==
                                            MessageType.userMessageTextOnly ||
                                        message.messageType ==
                                            MessageType.userMessageWithImage;

                                    return AiMessage(
                                      isUser: isUser,
                                      message: message.message,
                                      profilePictureUrl: _profilePictureUrl,
                                      imageUrl: message.imageUrl,
                                      onCopyIconPressed: _copyToClipboard,
                                      isLoadingResponse: _loadingResponse &&
                                          index + 1 ==
                                              _conversationHistory.length,
                                    );
                                  },
                                ),
                              ),
                            ),
                      if (_showError)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      _showTokenMessage
                          ? Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10.0,
                                vertical: 15.0,
                              ),
                              child: _getTokenExceededMessage(context),
                            )
                          : buildTextInputFields(),
                    ],
                  ),
                  if (_showScrollToBottomButton)
                    Positioned(
                      bottom: 150,
                      right: 20,
                      child: FloatingActionButton(
                        mini: true,
                        onPressed: _scrollToBottom,
                        child: const Icon(Icons.arrow_downward),
                      ),
                    ),
                  // Tab to allow for resizing of widget
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onHorizontalDragUpdate: (details) {
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
                        child: MouseRegion(
                          cursor: SystemMouseCursors.resizeColumn,
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    ); 
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        _sendMessage();
      } else if (event.logicalKey == LogicalKeyboardKey.control ||
          event.logicalKey == LogicalKeyboardKey.meta) {
        setState(() {
          _isPasting = true;
        });
      }
    } else if (event is KeyUpEvent &&
        (event.logicalKey == LogicalKeyboardKey.control ||
            event.logicalKey == LogicalKeyboardKey.meta)) {
      setState(() {
        _isPasting = false;
      });
    }
  }

  Widget buildTopBar() {
    return Container(
      height: 60,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          Theme(
            data: ThemeData(
              popupMenuTheme: const PopupMenuThemeData(
                  elevation: 5, color: Color.fromRGBO(57, 57, 57, 1)),
            ),
            child: PopupMenuButton(
              itemBuilder: (context) {
                return [
                  PopupMenuItem(
                    onTap: () async {
                      await showInfoDialog();
                    },
                    child: const PopupMenuDetails(
                      icon: Icons.info_outline,
                      text: 'Info',
                    ),
                  ),
                  PopupMenuItem(
                    onTap: () async {
                      await showClearChatDialog();
                    },
                    child: const PopupMenuDetails(
                      icon: Icons.delete_outline_sharp,
                      text: 'Clear',
                    ),
                  ),
                ];
              },
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.more_horiz),
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget buildTextInputFields() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20.0),
          color: kFlourishAliceBlue,
        ),
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_imageFile != null)
              ImagePreview(
                imageFile: _imageFile,
                onDelete: () => setState(() => _imageFile = null),
              ),
            TextField(
              controller: _textEditingController,
              focusNode: _textInputFocusNode,
              cursorColor: kFlourishBlackish,
              maxLines: 7,
              minLines: 1,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                focusColor: kFlourishBlackish,
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: kFlourishBlackish, width: 0.1),
                ),
                hoverColor: kFlourishBlackish,
                hintText: 'Ask me anything...',
                border: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.transparent, width: 0.1),
                ),
              ),
              inputFormatters: [
                LengthLimitingTextInputFormatter(1000),
                if (_isPasting) NoEnterInputFormatter(),
              ],
              onChanged: (text) {
                setState(() {
                  numCharacters = text.length;
                });
                if (text.contains('\n')) {
                  _textEditingController.text = text.replaceAll('\n', '');
                  _textEditingController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _textEditingController.text.length),
                  );
                }
              },
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(Icons.image_outlined),
                  onPressed: _pickImage,
                ),
                const Spacer(),
                Text('$numCharacters/1000'),
                const SizedBox(width: 15.0),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _loadingImage ? null : _sendMessage,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> showClearChatDialog() async {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: kFlourishAliceBlue,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Delete chat?',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 10),
              const Divider(
                color: Colors.grey,
                thickness: 1,
              ),
            ],
          ),
          content: const Text('This will delete all messages in the chat.'),
          actions: [
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel',
                  style: GoogleFonts.inter(
                      color: Colors.black, fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.of(context).pop();
                _clearChat();
              },
              child: Text(
                'Clear',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> showInfoDialog() async {
    int tokensUsedToday = await _openaiService.getTokensUsedToday();
    final int tokenLimit = _openaiService.getTokenLimit();

    if (tokensUsedToday > tokenLimit) {
      tokensUsedToday = tokenLimit;
    }

    String tokensUsedTodayStr =
        NumberFormat.decimalPattern().format(tokensUsedToday);
    String tokenLimitStr = NumberFormat.decimalPattern().format(tokenLimit);

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: kFlourishAliceBlue,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const Text('Token Details'),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    Navigator.of(context).pop(); // Close the dialog
                  },
                ),
              ],
            ),
            content: SizedBox(
              height: 50,
              child: tokenLimit == 0
                  ? Text(
                      'Tokens used today: $tokensUsedTodayStr / ∞',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.normal,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tokens used today: $tokensUsedTodayStr / $tokenLimitStr',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 20),
                        LinearProgressIndicator(
                          value: tokensUsedToday / tokenLimit,
                          backgroundColor: Colors.grey[300],
                          valueColor:
                              const AlwaysStoppedAnimation(kFlourishAdobe),
                        ),
                      ],
                    ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  widget.onUpgradePressed();
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: kFlourishAdobe,
                    foregroundColor: Colors.white),
                child: Text(
                  'Get more tokens',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.black),
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(
                  'Close',
                  style: GoogleFonts.inter(
                    color: Colors.black,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
            ],
          );
        },
      );
    }
  }

  Widget _getTokenExceededMessage(BuildContext context) {
    /*
    final resetTime = DateTime.now().add(const Duration(days: 1)).toLocal();
    final formattedTime = DateFormat('MMMM d, y').format(resetTime);
  */
    return RichText(
      text: TextSpan(
        children: [
          const TextSpan(
            text: 'You have exceeded the token limit for today. ',
            style: TextStyle(color: kFlourishLightBlackish, fontSize: 12),
          ),
          TextSpan(
            text: 'Upgrade for more',
            style: const TextStyle(
              color: kFlourishAdobe, // Set the color of "Upgrade for more"
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                // Navigate to the upgrade page
                widget.onUpgradePressed();
              },
          ),
        ],
      ),
    );
  }

  Future<void> _clearChat() async {
    try {
      setState(() {
        _conversationHistory.clear();
      });
      await _openaiService.clearConversationHistory();
    } catch (e) {
      _logger.e('Failed to clear chat: $e');
      setState(() {
        _showError = true;
        _errorMessage = 'Failed to clear chat. Please try again.';
      });
    }
  }

  Future<void> _pickImage() async {
    setState(() {
      _imageFile = null;
      _imageUrl = null;
      _loadingImage = true;
    });
    final file = await ImagePickerWeb.getImageAsFile();
    if (file == null) {
      setState(() {
        _loadingImage = false;
      });
      return;
    }

    final reader = html.FileReader();
    reader.onLoadEnd.listen((_) {
      setState(() {
        _imageFile = reader.result as Uint8List;
      });
    });
    reader.readAsArrayBuffer(file);

    final filename = const Uuid().v4();
    final ref = FirebaseStorage.instance.ref().child('openai/$filename');
    await ref.putBlob(file);
    _imageUrl = await ref.getDownloadURL();

    setState(() {
      _loadingImage = false;
    });
  }

  Future<void> _disposeImage() async {
    if (_imageUrl == null) return;
    final ref = FirebaseStorage.instance.refFromURL(_imageUrl!);
    await ref.delete();
  }
}

class ImagePreview extends StatefulWidget {
  const ImagePreview({
    super.key,
    required this.imageFile,
    required this.onDelete,
  });

  final Uint8List? imageFile;
  final VoidCallback onDelete;

  @override
  State<ImagePreview> createState() => _ImagePreviewState();
}

class _ImagePreviewState extends State<ImagePreview> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                height: 140,
                width: 140,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    fit: BoxFit.cover,
                    image: MemoryImage(widget.imageFile!),
                  ),
                ),
              ),
              if (_isHovering)
                Positioned(
                  right: 0,
                  child: IconButton(
                    icon: const Icon(Icons.remove_circle_outline_outlined,
                        color: Colors.white),
                    onPressed: widget.onDelete,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10.0),
        ],
      ),
    );
  }
}

class NoEnterInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.contains('\n')) {
      return oldValue;
    }
    return newValue;
  }
}
