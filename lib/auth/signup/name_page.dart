import 'package:flourish_web/animations.dart';
import 'package:flourish_web/api/auth_service.dart';
import 'package:flourish_web/auth/login_page.dart';
import 'package:flourish_web/auth/signup/create_password.dart';
import 'package:flourish_web/auth/unknown_error.dart';
import 'package:flourish_web/auth/widgets/error_message.dart';
import 'package:flourish_web/auth/widgets/textfield.dart';
import 'package:flourish_web/colors.dart';
import 'package:flourish_web/studyroom/study_page.dart';
import 'package:flutter/material.dart';

class EnterNamePage extends StatefulWidget {
  const EnterNamePage(
      {required this.username, required this.password, super.key});

  final String username;
  final String password;

  @override
  State<EnterNamePage> createState() => _EnterNamePageState();
}

class _EnterNamePageState extends State<EnterNamePage> {
  final TextEditingController _textController = TextEditingController();

  bool _error = false;
  String _errorMessage = '';

  bool _unknownError = false;

  bool _loading = false;

  final _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: kFlourishBlackish,
        body: Center(
          child: SingleChildScrollView(
            child: Center(
              child: SizedBox(
                width: 350,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    buildHeading(),
                    const SizedBox(height: 30),
                    if (_unknownError) const UnknownError(),
                    buildTextFields(),
                    const SizedBox(height: 20),
                    _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: kFlourishAdobe,
                            ),
                          )
                        : ElevatedButton(
                            onPressed: next,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kFlourishAdobe,
                              minimumSize: const Size(350, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text(
                              'Sign Up',
                              style: TextStyle(
                                color: kFlourishBlackish,
                                fontSize: 16,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                    const SizedBox(height: 40),
                    Container(
                      height: 0.5,
                      width: 550,
                      color: kFlourishAliceBlue.withOpacity(0.7),
                    ),
                    const SizedBox(height: 40),
                    buildBackToLoginWidgets(),
                  ],
                ),
              ),
            ),
          ),
        ));
  }

  Widget buildHeading() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        IconButton(
          onPressed: () {
            Navigator.of(context).push(
                noTransition(CreatePasswordPage(username: widget.username)));
          },
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: kFlourishAliceBlue),
        ),
        const SizedBox(width: 50),
        Center(
          child: Container(
            height: 60,
            width: 60,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/brand/logo.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Flourish',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: kFlourishAliceBlue,
            fontSize: 24,
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget buildTextFields() {
    return Column(
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Text(
                'Name',
                style: TextStyle(
                  color: kFlourishAliceBlue,
                  fontSize: 17,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'This name will appear on your profile',
            style: TextStyle(
              color: kFlourishLightBlackish,
              fontSize: 13,
              fontFamily: 'Inter',
            ),
          ),
        ),
        const SizedBox(height: 13),
        LoginTextField(
          controller: _textController,
          onChanged: (_) {
            setState(() {
              _error = false;
              _errorMessage = '';
            });
          },
          hintText: '',
          keyboardType: TextInputType.name,
          valid: !_error,
        ),
        if (_error) ErrorMessage(message: _errorMessage),
      ],
    );
  }

  Widget buildBackToLoginWidgets() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Already have an account?',
          style: TextStyle(
            color: kFlourishAliceBlue,
            fontSize: 15,
            fontFamily: 'Inter',
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).push(noTransition(const LoginPage()));
          },
          style: TextButton.styleFrom(
            padding: const EdgeInsets.all(0),
          ),
          child: const Text(
            'Log in',
            style: TextStyle(
              color: kFlourishAliceBlue,
              fontSize: 15,
              fontFamily: 'Inter',
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
              decorationColor: kFlourishAliceBlue,
            ),
          ),
        ),
      ],
    );
  }

  void next() async {
    if (_textController.text.isEmpty) {
      setState(() {
        _error = true;
        _errorMessage = 'Enter a name for your profile';
      });
      return;
    }
    setState(() {
      _loading = true;
    });

    try {
      _authService.signUp(
          widget.username, widget.password, _textController.text);
    } catch (e) {
      setState(() {
        _unknownError = true;
      });
    }

    setState(() {
      _loading = false;
    });
    Navigator.of(context).push(noTransition(const StudyRoom()));
  }
}

class PasswordChecklistItem extends StatefulWidget {
  const PasswordChecklistItem({
    required this.text,
    required this.isChecked,
    required this.error,
    super.key,
  });

  final String text;
  final bool isChecked;
  final bool error;

  @override
  State<PasswordChecklistItem> createState() => _PasswordChecklistItemState();
}

class _PasswordChecklistItemState extends State<PasswordChecklistItem> {
  @override
  Widget build(BuildContext context) {
    late final Color color;
    if (widget.isChecked) {
      color = const Color.fromRGBO(102, 255, 0, 1.0);
    } else {
      if (widget.error) {
        color = Colors.red;
      } else {
        color = kFlourishAliceBlue;
      }
    }
    return Row(
      children: [
        Icon(
          widget.isChecked ? Icons.check_circle : Icons.circle_outlined,
          color: color,
          size: 15,
        ),
        const SizedBox(width: 5),
        Text(
          widget.text,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }
}
