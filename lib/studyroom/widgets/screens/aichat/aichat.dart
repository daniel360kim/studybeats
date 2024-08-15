import 'dart:ui';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flourish_web/secrets.dart';
import 'package:flourish_web/studyroom/widgets/screens/aichat/aimessage.dart';
import 'package:universal_html/html.dart' as html;
import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:flourish_web/api/auth/auth_service.dart';
import 'package:flourish_web/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker_web/image_picker_web.dart';
import 'package:uuid/uuid.dart';

class UserMessage {
  final String message;
  final Uint8List? imageFile;

  UserMessage(this.message, this.imageFile);
}

class AiChat extends StatefulWidget {
  const AiChat({required this.onClose, super.key});

  final VoidCallback onClose;

  @override
  State<AiChat> createState() => _AiChatState();
}

class _AiChatState extends State<AiChat> {
  final FocusNode _keyboardListenerFocusNode = FocusNode();
  final FocusNode _textInputFocusNode = FocusNode();
  final TextEditingController _textEditingController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final OpenAI openAi = OpenAI.instance.build(
    token: OPENAI_PROJECT_API_KEY,
    baseOption: HttpSetup(receiveTimeout: const Duration(seconds: 120)),
    enableLog: true,
  );
  final AuthService _authService = AuthService();

  bool _isPasting = false;
  bool _showScrollToBottomButton = false;
  bool _loadingResponse = false;
  bool _showError = false;
  String? _profilePictureUrl;
  Uint8List? _imageFile;
  String? _imageUrl;
  String _errorMessage = '';

  final List<UserMessage> _userMessages = [];
  final List<String> _aiMessages = [];
  final List<Map<String, dynamic>> _conversationHistory = [];
  int numCharacters = 0;

  @override
  void initState() {
    super.initState();
    _getProfileUrl();
    _scrollController.addListener(_scrollListener);
  }

  Future<void> _getProfileUrl() async {
    final url = await _authService.getProfilePictureUrl();
    setState(() {
      _profilePictureUrl = url;
    });
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
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.fastLinearToSlowEaseIn,
      );
    }
  }

  Future<void> _sendMessage() async {
    if (_imageFile == null) {
      await _sendTextOnly();
    } else {
      await _sendImage();
    }
  }

  Future<void> _sendTextOnly() async {
    if (_textEditingController.text.isEmpty || _loadingResponse) return;

    final uid = await _authService.getCurrentUserUid();
    final userMessage = _textEditingController.text;

    setState(() {
      _loadingResponse = true;
      _userMessages.add(UserMessage(userMessage, null));
      _conversationHistory.add({'role': 'user', 'content': userMessage});
      _textEditingController.clear();
      numCharacters = 0;
      FocusScope.of(context).requestFocus(_textInputFocusNode);
      _scrollToBottom();
      _aiMessages.add('');
      _showError = false;
    });

    try {
      final request = ChatCompleteText(
        user: uid,
        messages: _conversationHistory,
        maxToken: 1000,
        model: Gpt4OMiniChatModel(),
      );

      final response = await openAi.onChatCompletion(request: request);

      setState(() {
        _loadingResponse = false;
        _aiMessages.last = response!.choices.first.message!.content;
        _conversationHistory
            .add({'role': 'assistant', 'content': _aiMessages.last});
      });
    } catch (e) {
      setState(() {
        _loadingResponse = false;
        _showError = true;
        _errorMessage = 'Failed to get response from API: $e';
      });
    }
  }

  Future<void> _sendImage() async {
    if (_loadingResponse || _imageUrl == null) return;

    final uid = await _authService.getCurrentUserUid();
    final userMessage = _textEditingController.text;

    setState(() {
      _loadingResponse = true;
      _userMessages.add(UserMessage(userMessage, _imageFile));
      _aiMessages.add('');
      _imageFile = null;
      _showError = false;
    });

    try {
      final request = ChatCompleteText(
        user: uid,
        messages: [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': userMessage},
              {
                'type': 'image_url',
                'image_url': {'url': _imageUrl}
              }
            ]
          }
        ],
        maxToken: 1000,
        model: Gpt4OMiniChatModel(),
      );

      final response = await openAi.onChatCompletion(request: request);

      setState(() {
        _imageUrl = null;
        _aiMessages.last = response!.choices.first.message!.content;
        _conversationHistory
            .add({'role': 'assistant', 'content': _aiMessages.last});
        _loadingResponse = false;
      });
    } catch (e) {
      setState(() {
        _imageUrl = null;
        _loadingResponse = false;
        _showError = true;
        _errorMessage = 'Failed to get response from API: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: SizedBox(
        width: 400,
        height: MediaQuery.of(context).size.height - 120,
        child: KeyboardListener(
          focusNode: _keyboardListenerFocusNode,
          onKeyEvent: _handleKeyEvent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10.0),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Color(0xFFE0E7FF),
                      Color(0xFFF7F8FC),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Stack(
                  children: [
                    Column(
                      children: [
                        buildTopBar(),
                        Expanded(
                          child: ListView.builder(
                            controller: _scrollController,
                            itemCount:
                                _userMessages.length + _aiMessages.length,
                            itemBuilder: (context, index) {
                              final isUser = index.isEven;
                              final message = isUser
                                  ? _userMessages[index ~/ 2].message
                                  : _aiMessages[index ~/ 2];
                              final imageFile = isUser
                                  ? _userMessages[index ~/ 2].imageFile
                                  : null;

                              return AiMessage(
                                isUser: isUser,
                                message: message,
                                profilePictureUrl: _profilePictureUrl,
                                imageFile: imageFile,
                                onCopyIconPressed: _copyToClipboard,
                                isLoadingResponse: _loadingResponse &&
                                    index + 1 ==
                                        _aiMessages.length +
                                            _userMessages.length,
                              );
                            },
                          ),
                        ),
                        if (_showError)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              _errorMessage,
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        buildTextInputFields(),
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
                  ],
                ),
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
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final file = await ImagePickerWeb.getImageAsFile();
    if (file == null) return;

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
