
import 'package:cloud_firestore/cloud_firestore.dart';

class EmailValidator {
  final String email;

  EmailValidator(this.email);

  bool isEmailValid() {
    const String emailRegex =
        r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)'
        r'|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'
        r'\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+'
        r'[a-zA-Z]{2,}))$';
    final RegExp emailExp = RegExp(emailRegex);

    return emailExp.hasMatch(email);
  }

  Future<bool> doesUserExist() async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(email).get();
      return doc.exists;
    } catch (e) {
      throw Exception(e);
    }
  }
}

class PasswordValidator {
  final String password;

  PasswordValidator(this.password);

  bool isLengthRequirementMet() {
    return password.length >= 8;
  }

  bool isLetterRequirementMet() {
    return RegExp(r'[a-zA-Z]').hasMatch(password);
  }
}
