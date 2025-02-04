import 'package:studybeats/api/auth/auth_service.dart';
import 'package:studybeats/auth_pages/unknown_error.dart';
import 'package:studybeats/auth_pages/widgets/error_message.dart';
import 'package:studybeats/auth_pages/widgets/textfield.dart';
import 'package:studybeats/auth_pages/widgets/third_party_button.dart';
import 'package:studybeats/api/auth/validators.dart';
import 'package:studybeats/colors.dart';
import 'package:studybeats/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

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
  void initState() {
    if (_authService.isUserLoggedIn()) {
      context.goNamed(AppRoute.studyRoom.name);
    }
    super.initState();
    _keyboardListenerFocusNode.requestFocus();
  }

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
                              child: Text(
                                'Next',
                                style: GoogleFonts.inter(
                                  color: kFlourishBlackish,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
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
                            if (context.mounted) {
                              context.goNamed(AppRoute.studyRoom.name);
                            }
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
                              _unknownError = true;
                              _loading = false;
                            });
                          });
                        },
                        backgroundColor: Colors.transparent,
                        logoPath: 'assets/brand/microsoft.png',
                        text: 'Sign up with Microsoft',
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
          Text(
            'Sign up to start studying',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: kFlourishAliceBlue,
              fontSize: 36,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTextFields() {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Email address',
            style: GoogleFonts.inter(
              color: kFlourishAliceBlue,
              fontSize: 15,
              fontWeight: FontWeight.w600,
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
        Text(
          'Already have an account?',
          style: GoogleFonts.inter(
            color: kFlourishAliceBlue,
            fontSize: 15,
          ),
        ),
        TextButton(
          onPressed: () => context.goNamed(AppRoute.loginPage.name),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.all(0),
          ),
          child: Text(
            'Log in',
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

      const storage = FlutterSecureStorage();

      await storage.write(key: 'username', value: _emailTextController.text);

      if (mounted) {
        context.goNamed(AppRoute.createPasswordPage.name);
      }
    }
  }
}
