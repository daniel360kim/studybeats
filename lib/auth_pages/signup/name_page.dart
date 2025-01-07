import 'package:studybeats/api/auth/auth_service.dart';
import 'package:studybeats/auth_pages/unknown_error.dart';
import 'package:studybeats/auth_pages/widgets/error_message.dart';
import 'package:studybeats/auth_pages/widgets/textfield.dart';
import 'package:studybeats/colors.dart';
import 'package:studybeats/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

class EnterNamePage extends StatefulWidget {
  const EnterNamePage({super.key});

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
  void initState() {
    super.initState();
  }

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
                            child: Text(
                              'Sign Up',
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
            context.goNamed(AppRoute.createPasswordPage.name, extra: {});
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
                'Name',
                style: GoogleFonts.inter(
                  color: kFlourishAliceBlue,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'This name will appear on your profile',
            style: GoogleFonts.inter(
              color: kFlourishLightBlackish,
              fontSize: 13,
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
      const storage = FlutterSecureStorage();

      final username = await storage.read(key: 'username');
      final password = await storage.read(key: 'password');

      await _authService.signUp(username!, password!, _textController.text);

      if (mounted) {
        context.goNamed(AppRoute.studyRoom.name);
      }
    } catch (e) {
      setState(() {
        _unknownError = true;
      });
    }

    setState(() {
      _loading = false;
    });
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
