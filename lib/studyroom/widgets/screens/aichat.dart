import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:flourish_web/api/auth_service.dart';
import 'package:flourish_web/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class AiChat extends StatefulWidget {
  const AiChat({super.key});

  @override
  State<AiChat> createState() => _AiChatState();
}

class _AiChatState extends State<AiChat> {
  final FocusNode _keyboardListenerFocusNode = FocusNode();
  final FocusNode _textInputFocusNode = FocusNode();

  final TextEditingController _textEditingController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final OpenAI openAi = OpenAI.instance.build(
      token: dotenv.env['OPENAI_PROJECT_API_KEY'],
      baseOption: HttpSetup(receiveTimeout: const Duration(seconds: 120)),
      enableLog: true);

  bool _isPasting = false;
  bool _showScrollToBottomButton = false;

  String? _profilePictureUrl;

  List<String> _userMessages = [];
  List<String> _aiMessages = [];

  @override
  void initState() {
    super.initState();
    _getProfileUrl();
    _scrollController.addListener(_scrollListener);
  }

  void _getProfileUrl() async {
    await AuthService().getProfilePictureUrl().then((value) {
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
    if (_textEditingController.text.isNotEmpty) {
      final userMessage = _textEditingController.text;

      setState(() {
        _userMessages.add(userMessage);
      });

      // Clear the text field and ensure it's focused again
      _textEditingController.clear();
      FocusScope.of(context).requestFocus(_textInputFocusNode);
      _scrollToBottom();

      final request = ChatCompleteText(messages: [
        Map.of({'role': 'user', 'content': userMessage})
      ], maxToken: 1000, model: Gpt4OMiniChatModel());

      _aiMessages.add('');

      openAi.onChatCompletionSSE(request: request).listen(
        (response) {
          setState(() {
            _aiMessages.last += response.choices!.first.message!.content;
          });
          _scrollToBottom();
        },
        onError: (error) {
          print(error.toString());
        },
        
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const BorderRadius borderRadius =
        BorderRadius.only(topLeft: Radius.circular(40.0));
    return SizedBox(
      width: 400,
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
                padding: const EdgeInsets.all(15),
                decoration: const BoxDecoration(
                  color: Color.fromRGBO(170, 170, 170, 1),
                  borderRadius: borderRadius,
                ),
                child: Stack(
                  children: [
                    Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            controller: _scrollController,
                            itemCount:
                                _userMessages.length + _aiMessages.length,
                            itemBuilder: (context, index) {
                              final isUser = index % 2 == 0;
                              final message = isUser
                                  ? _userMessages[index ~/ 2]
                                  : _aiMessages[index ~/ 2];

                              return buildMessage(isUser, message);
                            },
                          ),
                        ),
                        buildTextInputFields(),
                      ],
                    ),
                    Visibility(
                      visible: _showScrollToBottomButton,
                      child: Positioned(
                        bottom: 80,
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
    );
  }

  Widget buildTextInputFields() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
              child: TextField(
            controller: _textEditingController,
            focusNode: _textInputFocusNode,
            cursorColor: kFlourishBlackish,
            maxLines:
                7, // Set this to null to let the TextField grow vertically
            minLines: 1, // Start with a single line
            textInputAction: TextInputAction
                .newline, // Set action to newline (multiline input)
            decoration: InputDecoration(
              focusColor: kFlourishBlackish,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(
                  color: kFlourishBlackish, // Set the border color when focused
                ),
              ),
              hoverColor: kFlourishBlackish,
              hintText: 'Type a message',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            inputFormatters: [
              if (_isPasting)
                NoEnterInputFormatter() // keep a new line from forming in the next message when enter is sent
              // Add more formatters if needed
            ],
            onChanged: (text) {
              if (text.contains('\n')) {
                // Remove the newline character
                _textEditingController.text = text.replaceAll('\n', '');
                // Place the cursor at the end of the text
                _textEditingController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _textEditingController.text.length));
              }
            },
          )),
          IconButton(
            icon: const Icon(Icons.arrow_upward_sharp),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }

  Container buildMessage(bool isUser, String message) {
    late final String messageTitle;
    late final Widget profileImage;

    if (isUser) {
      messageTitle = 'You';
      if (_profilePictureUrl != null) {
        profileImage = SizedBox(
          height: 20,
          width: 20,
          child: CircleAvatar(
            backgroundImage: CachedNetworkImageProvider(_profilePictureUrl!),
          ),
        );
      }
    } else {
      profileImage = Container(
        height: 10,
        width: 10,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: kFlourishPurple,
        ),
      );
      messageTitle = 'ChatGPT';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isUser ? Colors.blue[100] : Colors.green[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              profileImage,
              const SizedBox(width: 5),
              SelectableText(
                messageTitle,
                style: const TextStyle(
                  fontSize: 15,
                  fontFamily: 'Inter',
                  color: kFlourishBlackish,
                  fontWeight: FontWeight.bold,
                ),
              )
            ],
          ),
          Row(
            children: [
              Expanded(
                child: isUser
                    ? SelectableText(
                        message,
                        style: const TextStyle(fontSize: 16),
                      )
                    : MarkdownBody(
                        selectable: true,
                        data: message,
                        styleSheet: MarkdownStyleSheet(
                          p: const TextStyle(fontSize: 16),
                        ),
                      ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                onPressed: () => _copyToClipboard(message),
              ),
            ],
          ),
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
