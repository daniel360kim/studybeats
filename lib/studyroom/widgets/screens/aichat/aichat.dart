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
  String message;
  Uint8List? imageFile;

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
      enableLog: true);

  bool _isPasting = false;
  bool _showScrollToBottomButton = false;
  bool _loadingResponse = false;

  String? _profilePictureUrl;

  final List<UserMessage> _userMessages = [];
  final List<String> _aiMessages = [];
  final List<Map<String, dynamic>> _conversationHistory = [];

  Uint8List? _imageFile;
  String? _imageUrl;

  final _authService = AuthService();

  int numCharacters = 0;

  @override
  void initState() {
    super.initState();
    _getProfileUrl();
    _scrollController.addListener(_scrollListener);
  }

  void _getProfileUrl() async {
    await _authService.getProfilePictureUrl().then((value) {
      setState(() {
        _profilePictureUrl = value;
      });
    });
  }

  void _scrollListener() {
    if (_scrollController.position.pixels <
        _scrollController.position.maxScrollExtent) {
      setState(() {
        _showScrollToBottomButton = true;
      });
    } else {
      setState(() {
        _showScrollToBottomButton = false;
      });
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _textEditingController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
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

  void _sendMessage() {
    setState(() {
      numCharacters = 0;
    });
    if (_imageFile == null) {
      _sendTextOnly();
    } else {
      _sendImage();
    }
  }

  void _sendTextOnly() async {
    if (_textEditingController.text.isNotEmpty && !_loadingResponse) {
      final uid = await _authService.getCurrentUserUid();
      final userMessage = _textEditingController.text;

      _conversationHistory.add({'role': 'user', 'content': userMessage});

      setState(() {
        _loadingResponse = true;
        _userMessages.add(UserMessage(userMessage, null));
      });

      // Clear the text field and ensure it's focused again
      _textEditingController.clear();
      FocusScope.of(context).requestFocus(_textInputFocusNode);
      _scrollToBottom();

      final request = ChatCompleteText(
          user: uid,
          messages: _conversationHistory,
          maxToken: 1000,
          model: Gpt4OMiniChatModel());

      setState(() {
        _aiMessages.add('');
      });

      final response = await openAi.onChatCompletion(request: request);

      for (var element in response!.choices) {
        setState(() {
          _aiMessages.last = (element.message!.content);
          _loadingResponse = false;
          _conversationHistory
              .add({'role': 'assistant', 'content': element.message!.content});
        });
      }
    }
  }

  void _sendImage() async {
    if (_loadingResponse || _imageUrl == null) return;

    final uid = await _authService.getCurrentUserUid();

    late final String userMessage;
    if (_textEditingController.text.isEmpty) {
      userMessage = '';
    } else {
      userMessage = _textEditingController.text;
    }

    _textEditingController.clear();

    _conversationHistory.add({
      'role': 'user',
      'content': [
        {'type': 'text', 'text': userMessage},
        {
          'type': 'image_url',
          'image_url': {'url': _imageUrl}
        }
      ]
    });

    setState(() {
      _loadingResponse = true;
      _userMessages.add(UserMessage(userMessage, _imageFile));
      _aiMessages.add('');
      _imageFile = null;
    });

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
      String? responseText = response?.choices[0].message!.content;
      _aiMessages.last = responseText!;
      _loadingResponse = false;
      _conversationHistory.add({'role': 'assistant', 'content': responseText});
    });
  }

  @override
  Widget build(BuildContext context) {
    const BorderRadius borderRadius = BorderRadius.all(Radius.circular(10.0));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: SizedBox(
        width: 400,
        height: MediaQuery.of(context).size.height - 80 - 40,
        child: KeyboardListener(
          focusNode: _keyboardListenerFocusNode,
          onKeyEvent: (event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.enter) {
              _sendMessage();
            }

            if (event is KeyDownEvent &&
                (event.logicalKey == LogicalKeyboardKey.control ||
                    event.logicalKey == LogicalKeyboardKey.meta)) {
              setState(() {
                _isPasting = true;
              });
            }

            if (event is KeyUpEvent &&
                (event.logicalKey == LogicalKeyboardKey.control ||
                    event.logicalKey == LogicalKeyboardKey.meta)) {
              setState(() {
                _isPasting = false;
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.only(left: 10),
            height: MediaQuery.of(context).size.height - 80,
            child: ClipRRect(
              borderRadius: borderRadius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Color(0xFFE0E7FF), // Light purple (at the bottom)
                        Color(
                            0xFFF7F8FC) // Lighter almost white (at the top)Ending color at the top
                      ],
                    ),
                    borderRadius: borderRadius,
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
                                final isUser = index % 2 == 0;
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
                                  onCopyIconPressed: (value) =>
                                      _copyToClipboard(value),
                                  isLoadingResponse: _loadingResponse &&
                                      index + 1 ==
                                          _aiMessages.length +
                                              _userMessages
                                                  .length, //only set loading to true if it is the last message
                                );
                              },
                            ),
                          ),
                          buildTextInputFields(),
                        ],
                      ),
                      Visibility(
                        visible: _showScrollToBottomButton,
                        child: Positioned(
                          bottom: 150,
                          right: 20,
                          child: FloatingActionButton(
                            mini: true,
                            onPressed: _scrollToBottom,
                            child: const Icon(Icons.arrow_downward),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildTopBar() {
    return Container(
        height: 60,
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          children: [
            const Spacer(),
            IconButton(onPressed: widget.onClose, icon: const Icon(Icons.close))
          ],
        ));
  }

  Widget buildTextInputFields() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        decoration: const BoxDecoration(
            borderRadius: BorderRadius.all(
              Radius.circular(20.0),
            ),
            color: kFlourishAliceBlue),
        padding: const EdgeInsets.symmetric(
          vertical: 10.0,
          horizontal: 10.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_imageFile != null)
              ImagePreview(
                  imageFile: _imageFile,
                  onDelete: () {
                    setState(() {
                      _imageFile = null;
                    });
                  }),
            TextField(
              controller: _textEditingController,
              focusNode: _textInputFocusNode,
              cursorColor: kFlourishBlackish,
              maxLines:
                  7, // Set this to null to let the TextField grow vertically
              minLines: 1, // Start with a single line
              textInputAction: TextInputAction
                  .newline, // Set action to newline (multiline input)
              decoration: const InputDecoration(
                focusColor: kFlourishBlackish,
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color:
                        kFlourishBlackish, // Set the border color when focused
                    width: 0.1,
                  ),
                ),
                hoverColor: kFlourishBlackish,
                hintText: 'Ask me anything...',
                border: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors
                        .transparent, // Set the border color when not focused
                    width: 0.1,
                  ),
                ),
              ),
              inputFormatters: [
                LengthLimitingTextInputFormatter(1000),

                if (_isPasting)
                  NoEnterInputFormatter() // keep a new line from forming in the next message when enter is sent
                // Add more formatters if needed
              ],
              onChanged: (text) {
                setState(() {
                  numCharacters = text.length;
                });
                if (text.contains('\n')) {
                  // Remove the newline character
                  _textEditingController.text = text.replaceAll('\n', '');
                  // Place the cursor at the end of the text
                  _textEditingController.selection = TextSelection.fromPosition(
                      TextPosition(offset: _textEditingController.text.length));
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

  void _pickImage() async {
    final file = await ImagePickerWeb.getImageAsFile();

    // load the file for optimistic UI updates
    final reader = html.FileReader();
    reader.onLoadEnd.listen((event) {
      setState(() {
        _imageFile = reader.result as Uint8List;
      });
    });

    reader.readAsArrayBuffer(file!);

    final filename = const Uuid().v4();
    final ref = FirebaseStorage.instance.ref().child('openai/$filename');
    await ref.putBlob(file);

    _imageUrl = await ref.getDownloadURL();
  }

  void _disposeImage() async {
    if (_imageUrl == null) return;
    final ref = FirebaseStorage.instance.refFromURL(_imageUrl!);
    await ref.delete();
  }
}

class ImagePreview extends StatefulWidget {
  const ImagePreview({
    super.key,
    required Uint8List? imageFile,
    required this.onDelete,
  }) : _imageFile = imageFile;

  final Uint8List? _imageFile;
  final VoidCallback onDelete;

  @override
  State<ImagePreview> createState() => _ImagePreviewState();
}

class _ImagePreviewState extends State<ImagePreview> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (event) {
        setState(() {
          _isHovering = true;
        });
      },
      onExit: (event) {
        setState(() {
          _isHovering = false;
        });
      },
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                height: 140,
                width: 140,
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                    image: DecorationImage(
                  fit: BoxFit.cover,
                  image: MemoryImage(widget._imageFile!),
                )),
              ),
              if (_isHovering)
                Positioned(
                  right: 0,
                  child: IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline_outlined,
                      color: Colors.white,
                    ),
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
    // Check if the new text contains newline characters
    if (newValue.text.contains('\n')) {
      // Return old value to ignore the newline input
      return oldValue;
    }
    // Otherwise, accept the new value
    return newValue;
  }
}
