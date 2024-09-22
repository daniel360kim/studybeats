import 'package:firebase_auth/firebase_auth.dart';
import 'package:flourish_web/api/auth/auth_service.dart';
import 'package:flourish_web/auth/unknown_error.dart';
import 'package:flourish_web/auth/widgets/error_message.dart';
import 'package:flourish_web/auth/widgets/textfield.dart';
import 'package:flourish_web/auth/widgets/third_party_button.dart';
import 'package:flourish_web/api/auth/validators.dart';
import 'package:flourish_web/colors.dart';
import 'package:flourish_web/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameTextController = TextEditingController();

  final TextEditingController _passwordTextController = TextEditingController();

  bool _passwordVisible = false;

  bool _validUsername = true;
  bool _validPassword = true;

  String _usernameErrorMessage = '';
  String _passwordErrorMessage = '';

  bool _error = false;

  bool _loading = false;

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
              login();
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
                      const SizedBox(height: 40),
                      if (_error) const UnknownError(),
                      CredentialSigninButton(
                        onPressed: () {
                          setState(() {
                            _loading = true;
                          });
                          _authService.signUpInWithGoogle().then((value) {
                            setState(() {
                              _loading = false;
                            });
                            if (context.mounted) {
                              context.goNamed(AppRoute.studyRoom.name);
                            }
                          }).catchError((error) {
                            setState(() {
                              error = true;
                              _loading = false;
                            });
                          });
                        },
                        backgroundColor: Colors.transparent,
                        logoPath: 'assets/brand/google.png',
                        text: 'Sign in with Google',
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
                            if (context.mounted) {
                              context.goNamed(AppRoute.studyRoom.name);
                            }
                          }).catchError((error) {
                            setState(() {
                              error = true;
                              _loading = false;
                            });
                          });
                        },
                        backgroundColor: Colors.transparent,
                        logoPath: 'assets/brand/microsoft.png',
                        text: 'Sign in with Microsoft',
                      ),
                      const SizedBox(height: 40),
                      Container(
                        height: 0.5,
                        width: 550,
                        color: kFlourishAliceBlue.withOpacity(0.7),
                      ),
                      const SizedBox(height: 20),
                      buildTextFields(),
                      const SizedBox(height: 15),
                      _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: kFlourishAdobe,
                              ),
                            )
                          : ElevatedButton(
                              onPressed: login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kFlourishLightBlue,
                                minimumSize: const Size(350, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: Text(
                                'Log in',
                                style: GoogleFonts.inter(
                                  color: kFlourishBlackish,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                      const SizedBox(height: 20),
                      buildSignupWidgets(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ));
  }

  Widget buildHeading() {
    return Column(
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
        Text(
          'Log In',
          style: GoogleFonts.inter(
            color: kFlourishAliceBlue,
            fontSize: 36,
            fontWeight: FontWeight.w600,
          ),
        )
      ],
    );
  }

  Widget buildTextFields() {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Email',
            style: GoogleFonts.inter(
              color: kFlourishAliceBlue,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 13),
        LoginTextField(
          controller: _usernameTextController,
          onChanged: (_) {},
          hintText: 'Email',
          keyboardType: TextInputType.emailAddress,
          valid: _validUsername,
        ),
        _validUsername
            ? const SizedBox(height: 20)
            : ErrorMessage(
                message: _usernameErrorMessage,
              ),
        Row(
          children: [
            Text(
              'Password',
              style: GoogleFonts.inter(
                color: kFlourishAliceBlue,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            IconButton(
              style: ButtonStyle(
                padding: WidgetStateProperty.all(const EdgeInsets.all(0)),
              ),
              icon: Icon(
                size: 20,
                _passwordVisible ? Icons.visibility : Icons.visibility_off,
                color: kFlourishAliceBlue,
              ),
              onPressed: () {
                setState(() {
                  _passwordVisible = !_passwordVisible;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 5),
        LoginTextField(
          controller: _passwordTextController,
          onChanged: (value) {},
          hintText: 'Password',
          keyboardType: TextInputType.visiblePassword,
          obscureText: !_passwordVisible,
          valid: _validPassword,
        ),
        _validPassword
            ? const SizedBox(height: 10)
            : ErrorMessage(
                message: _passwordErrorMessage,
              ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {},
            child: Text(
              'Forgot password?',
              style: GoogleFonts.inter(
                color: kFlourishAliceBlue,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: kFlourishAliceBlue,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildSignupWidgets() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Don\'t have an account? ',
          style: GoogleFonts.inter(
            color: kFlourishAliceBlue,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        TextButton(
          style: ButtonStyle(
            padding: WidgetStateProperty.all(const EdgeInsets.all(0)),
          ),
          onPressed: () {
            context.goNamed(AppRoute.signUpPage.name);
          },
          child: Text(
            'Sign up',
            style: GoogleFonts.inter(
              color: kFlourishAliceBlue,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
              decorationColor: kFlourishAliceBlue,
            ),
          ),
        ),
      ],
    );
  }

  bool validateEmail(String email) {
    const String emailRegex =
        r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)'
        r'|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'
        r'\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+'
        r'[a-zA-Z]{2,}))$';
    final RegExp emailExp = RegExp(emailRegex);

    return emailExp.hasMatch(email);
  }

  Future login() async {
    EmailValidator validator = EmailValidator(_usernameTextController.text);
    if (_usernameTextController.text.isEmpty) {
      setState(() {
        _validUsername = false;
        _usernameErrorMessage = 'Please enter a username';
      });
      return;
    } else if (!validator.isEmailValid()) {
      setState(() {
        _validUsername = false;
        _usernameErrorMessage = 'Please enter a valid email';
      });
      return;
    } else {
      setState(() {
        _validUsername = true;
        _usernameErrorMessage = '';
      });
    }

    if (_passwordTextController.text.isEmpty) {
      setState(() {
        _validPassword = false;
        _passwordErrorMessage = 'Please enter a password';
      });
      return;
    } else {
      setState(() {
        _validPassword = true;
        _passwordErrorMessage = '';
      });
    }

    try {
      setState(() {
        _loading = true;
      });
      await _authService.signIn(
        _usernameTextController.text,
        _passwordTextController.text,
      );
      setState(() {
        _loading = false;
      });
      if (mounted) context.goNamed(AppRoute.studyRoom.name);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        setState(() {
          _validUsername = false;
          _usernameErrorMessage = 'User not found';
          _loading = false;
        });
      } else if (e.code == 'invalid-credential') {
        setState(() {
          _validPassword = false;
          _passwordErrorMessage = 'Incorrect username or password';
          _loading = false;
        });
      } else {
        setState(() {
          _error = true;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }
}
