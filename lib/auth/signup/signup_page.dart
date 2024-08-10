import 'package:flourish_web/animations.dart';
import 'package:flourish_web/api/auth/auth_service.dart';
import 'package:flourish_web/auth/login_page.dart';
import 'package:flourish_web/auth/signup/create_password.dart';
import 'package:flourish_web/auth/unknown_error.dart';
import 'package:flourish_web/auth/widgets/error_message.dart';
import 'package:flourish_web/auth/widgets/textfield.dart';
import 'package:flourish_web/auth/widgets/third_party_button.dart';
import 'package:flourish_web/api/auth/validators.dart';
import 'package:flourish_web/colors.dart';
import 'package:flourish_web/studyroom/study_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final TextEditingController _emailTextController = TextEditingController();
  bool _validEmail = true;
  String _emailErrorMessage = '';

  bool _loading = false;

  bool _unknownError = false;

  final _authService = AuthService();

  final _keyboardListenerFocusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: kFlourishBlackish,
        body: KeyboardListener(
          focusNode: _keyboardListenerFocusNode,
          onKeyEvent: (event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.enter) {
              next();
            }
          },
          child: Center(
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
                                'Next',
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
                      CredentialSigninButton(
                        onPressed: () {
                          setState(() {
                            _loading = true;
                          });
                          _authService.signUpInWithGoogle().then((value) {
                            setState(() {
                              _loading = false;
                            });
                            Navigator.of(context)
                                .push(noTransition(const StudyRoom()));
                          }).catchError((e) {
                            setState(() {
                              _unknownError = true;
                              _loading = false;
                            });
                          });
                        },
                        backgroundColor: Colors.transparent,
                        logoPath: 'assets/brand/google.png',
                        text: 'Sign up with Google',
                        fontFamily: 'Roboto',
                      ),
                      const SizedBox(height: 10),
                      CredentialSigninButton(
                        onPressed: () {
                          setState(() {
                            _loading = true;
                          });
                          _authService.signUpInWithMicrosoft().then((value) {
                            setState(() {
                              _loading = false;
                            });
                            Navigator.of(context)
                                .push(noTransition(const StudyRoom()));
                          }).catchError((error) {
                            setState(() {
                              _unknownError = true;
                              _loading = false;
                            });
                          });
                        },
                        backgroundColor: Colors.transparent,
                        logoPath: 'assets/brand/microsoft.png',
                        text: 'Sign up with Microsoft',
                        fontFamily: 'SegoeUI',
                      ),
                      const SizedBox(height: 40),
                      buildBackToLoginWidgets(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ));
  }

  Widget buildHeading() {
    return Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 80,
            width: 80,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/brand/logo.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Sign up to start studying',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: kFlourishAliceBlue,
              fontSize: 36,
              fontFamily: 'Inter',
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTextFields() {
    return Column(
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Email address',
            style: TextStyle(
              color: kFlourishAliceBlue,
              fontSize: 15,
              fontFamily: 'Inter',
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 13),
        LoginTextField(
          controller: _emailTextController,
          onChanged: (_) {},
          hintText: 'name@domain.com',
          keyboardType: TextInputType.emailAddress,
          valid: _validEmail,
        ),
        _validEmail
            ? const SizedBox(height: 20)
            : ErrorMessage(
                message: _emailErrorMessage,
              ),
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

  Future next() async {
    setState(() {
      _loading = true;
    });

    final validator = EmailValidator(_emailTextController.text);
    if (_emailTextController.text.isEmpty) {
      setState(() {
        _validEmail = false;
        _emailErrorMessage = 'Email cannot be empty';
        _loading = false;
        return;
      });
    } else if (!validator.isEmailValid()) {
      setState(() {
        _validEmail = false;
        _emailErrorMessage = 'Invalid email address';
        _loading = false;
        return;
      });
    } else if (await validator.doesUserExist()) {
      setState(() {
        _loading = false;
        _validEmail = false;
        _emailErrorMessage = 'User already exists';
        _loading = false;
        return;
      });
    } else {
      setState(() {
        _validEmail = true;
        _emailErrorMessage = '';
      });

      Navigator.of(context).push(noTransition(
          CreatePasswordPage(username: _emailTextController.text)));
    }
  }
}
