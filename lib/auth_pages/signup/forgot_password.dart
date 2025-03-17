import 'package:studybeats/api/auth/auth_service.dart';
import 'package:studybeats/auth_pages/unknown_error.dart';
import 'package:studybeats/auth_pages/widgets/error_message.dart';
import 'package:studybeats/auth_pages/widgets/textfield.dart';
import 'package:studybeats/api/auth/validators.dart';
import 'package:studybeats/colors.dart';
import 'package:studybeats/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _emailTextController = TextEditingController();
  bool _validEmail = true;
  String _emailErrorMessage = '';
  bool _loading = false;
  bool _unknownError = false;
  bool _emailSent =
      false; // Determines whether to show the "check your email" view

  final _authService = AuthService();
  final _keyboardListenerFocusNode = FocusNode();

  @override
  void initState() {
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
              event.logicalKey == LogicalKeyboardKey.enter &&
              !_emailSent) {
            next();
          }
        },
        child: Center(
          child: SingleChildScrollView(
            child: SizedBox(
              width: 350,
              child: _emailSent
                  ? buildCheckEmailView()
                  : buildForgotPasswordForm(),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildForgotPasswordForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        buildHeadingForgotPassword(),
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
                  'Reset Password',
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
        buildBackToLoginWidgets(),
      ],
    );
  }

  Widget buildCheckEmailView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        buildHeadingCheckEmail(),
        const SizedBox(height: 30),
        if (_unknownError) const UnknownError(),
        buildInstructionsCheckEmail(),
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
                onPressed: resendEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kFlourishAdobe,
                  minimumSize: const Size(350, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  'Resend Email',
                  style: GoogleFonts.inter(
                    color: kFlourishBlackish,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
        const SizedBox(height: 40),
        buildBackToLoginWidgets(),
      ],
    );
  }

  Widget buildHeadingForgotPassword() {
    return Center(
      child: Column(
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
            'Reset password',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: kFlourishAliceBlue,
              fontSize: 36,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Enter your email address to reset your password.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: kFlourishAliceBlue,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildHeadingCheckEmail() {
    return Center(
      child: Column(
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
            'Check Your Email',
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
          onChanged: (_) {
            setState(() {
              _validEmail = true;
              _emailErrorMessage = '';
            });
          },
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

  Widget buildInstructionsCheckEmail() {
    return Column(
      children: [
        Text(
          'We just sent instructions to:',
          textAlign: TextAlign.left,
          style: GoogleFonts.inter(
            color: kFlourishAliceBlue,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _emailTextController.text,
          textAlign: TextAlign.left,
          style: GoogleFonts.inter(
            color: kFlourishAdobe,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Please check your inbox and follow the instructions to reset your password. If you did not receive the email, you can resend it below.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: kFlourishAliceBlue,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget buildBackToLoginWidgets() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Back to login?',
          style: GoogleFonts.inter(
            color: kFlourishAliceBlue,
            fontSize: 15,
          ),
        ),
        TextButton(
          onPressed: () => context.goNamed(AppRoute.loginPage.name),
          style: TextButton.styleFrom(padding: const EdgeInsets.all(0)),
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
      _unknownError = false;
    });
    final email = _emailTextController.text.trim();
    final validator = EmailValidator(email);

    if (email.isEmpty) {
      setState(() {
        _validEmail = false;
        _emailErrorMessage = 'Email cannot be empty';
        _loading = false;
      });
      return;
    } else if (!validator.isEmailValid()) {
      setState(() {
        _validEmail = false;
        _emailErrorMessage = 'Invalid email address';
        _loading = false;
      });
      return;
    } else if (!await validator.doesUserExist()) {
      setState(() {
        _validEmail = false;
        _emailErrorMessage = 'No account found with that email';
        _loading = false;
      });
      return;
    } else {
      setState(() {
        _validEmail = true;
        _emailErrorMessage = '';
      });
    }

    try {
      await _authService.sendResetPasswordEmail(email);
      setState(() {
        _emailSent = true;
      });
    } catch (e) {
      setState(() {
        _unknownError = true;
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future resendEmail() async {
    setState(() {
      _loading = true;
      _unknownError = false;
    });
    try {
      await _authService.sendResetPasswordEmail(_emailTextController.text);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset email re-sent. Check your inbox.'),
        ),
      );
    } catch (e) {
      setState(() {
        _unknownError = true;
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }
}
