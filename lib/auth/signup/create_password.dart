import 'package:studybeats/api/auth/validators.dart';
import 'package:studybeats/router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:studybeats/auth/widgets/error_message.dart';
import 'package:studybeats/auth/widgets/textfield.dart';
import 'package:studybeats/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class CreatePasswordPage extends StatefulWidget {
  const CreatePasswordPage({super.key});

  @override
  State<CreatePasswordPage> createState() => _CreatePasswordPageState();
}

class _CreatePasswordPageState extends State<CreatePasswordPage> {
  final TextEditingController _passwordController = TextEditingController();

  bool _leastCharactersRequirement = false;
  bool _containsLetterRequirement = false;
  bool _passwordVisible = false;

  final bool _error = false;
  final String _errorMessage = '';

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
                      buildTextFields(),
                      const SizedBox(height: 20),
                      passwordRequirements(),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: next,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kFlourishAdobe,
                          minimumSize: const Size(350, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text('Next',
                            style: GoogleFonts.inter(
                              color: kFlourishBlackish,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            )),
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
            context.goNamed(AppRoute.signUpPage.name);
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
        Text(
          'Studybeats',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: kFlourishAliceBlue,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget buildTextFields() {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Text(
                'Create a password',
                style: GoogleFonts.inter(
                  color: kFlourishAliceBlue,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                  onPressed: () {
                    setState(() {
                      _passwordVisible = !_passwordVisible;
                    });
                  },
                  icon: Icon(
                    _passwordVisible ? Icons.visibility : Icons.visibility_off,
                    color: kFlourishAliceBlue,
                  )),
            ],
          ),
        ),
        const SizedBox(height: 13),
        LoginTextField(
          controller: _passwordController,
          onChanged: (_) {
            updateRequirements();
          },
          hintText: '',
          keyboardType: TextInputType.visiblePassword,
          valid: !_error,
          obscureText: !_passwordVisible,
        ),
        _error
            ? ErrorMessage(
                message: _errorMessage,
              )
            : const SizedBox(height: 20),
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
            'Log In',
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

  Widget passwordRequirements() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Password must contain:',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: kFlourishAliceBlue,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        PasswordChecklistItem(
          text: '8 characters',
          isChecked: _leastCharactersRequirement,
          error: _error,
        ),
        const SizedBox(height: 5),
        PasswordChecklistItem(
          text: '1 letter',
          isChecked: _containsLetterRequirement,
          error: _error,
        ),
      ],
    );
  }

  void updateRequirements() {
    final passwordValidator = PasswordValidator(_passwordController.text);
    setState(() {
      _leastCharactersRequirement = passwordValidator.isLengthRequirementMet();
      _containsLetterRequirement = passwordValidator.isLetterRequirementMet();
    });
  }

  void next() async {
    const storage = FlutterSecureStorage();
    await storage.write(key: 'password', value: _passwordController.text);

    if (mounted) {
      context.goNamed(AppRoute.enterNamePage.name);
    }
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
          style: GoogleFonts.inter(
            fontSize: 12,
            color: color,
          ),
        ),
      ],
    );
  }
}
