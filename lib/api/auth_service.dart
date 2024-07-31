import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flourish_web/app_state.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:universal_html/html.dart' as html;
import 'package:uuid/uuid.dart';

const String defaultProfilePicture =
    'https://firebasestorage.googleapis.com/v0/b/flourish-web-fa343.appspot.com/o/default_profile.png?alt=media&token=7a7b0005-d9f8-4ddd-80a1-18dac9c93a22';

class AuthService {
  Future _createUserEmailPassword(String email, String password) async {
    try {
      return await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      // Email and password validation should have been checked before this
      print(e.code.toString());
    } catch (e) {
      throw Exception(e);
    }
  }

  Future _registerWithFirestore(String imageURL) async {
    try {
      return await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.email)
          .set({
        'uid': FirebaseAuth.instance.currentUser!.uid,
        'profilePicture': imageURL,
      });
    } catch (e) {
      print(e);
    }
  }

  Future _login(String email, String password) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      print(e.code.toString());
    } catch (e) {
      throw Exception(e);
    }
  }

  Future signUp(String email, String password) async {
    await _createUserEmailPassword(email, password);
    await _login(email, password);
    await _registerWithFirestore(defaultProfilePicture);
  }

  bool doesUserExistInFirebase() {
    final user = FirebaseAuth.instance.currentUser;
    return user != null;
  }

  Future signUpInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser =
          await googleSignIn.signInSilently();

      if (googleUser == null) {
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          throw Exception('Google sign in failed');
        }
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser!.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.email)
            .get();
        if (!doc.exists) {
          await _registerWithFirestore(user.photoURL!);
        }
      }
    } catch (e) {
      print(e);
    }
  }

  Future signUpInWithMicrosoft() async {
    final microsoftProvider = MicrosoftAuthProvider();
    microsoftProvider.addScope('User.Read.All');

    try {
      await FirebaseAuth.instance.signInWithPopup(microsoftProvider);
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.email)
            .get();
        if (!doc.exists) {
          print('Registering with firestore');
          print('Photo URL: ${user.photoURL}');
          print('Full name ${user.displayName}');
          if (user.photoURL == null) {
            _registerWithFirestore(defaultProfilePicture);
          } else {
            _registerWithFirestore(user.photoURL!);
          }
        }
      }
    } catch (e) {
      print(e);
    }
  }

  Future signIn(String email, String password) async {
    await _login(email, password);
  }

  Future<String> getProfilePictureUrl() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.email)
            .get();
        return doc.get('profilePicture');
      } else {
        throw Exception('User is not logged in');
      }
    } catch (e) {
      throw Exception(e);
    }
  }

  Future<DateTime> getAccountCreationDate() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return user.metadata.creationTime!;
    } else {
      throw Exception('User is not logged in');
    }
  }

  Future updateProfilePicture(html.File image) async {
    // Delete the old profile picture if the domain is firebase storage
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.email)
          .get();
      final oldProfilePicture = doc.get('profilePicture');
      if (oldProfilePicture.contains('firebasestorage.googleapis.com')) {
        final oldProfilePictureRef =
            FirebaseStorage.instance.refFromURL(oldProfilePicture);
        await oldProfilePictureRef.delete();
      }
    }

    final fileName = const Uuid().v4();
    final ref =
        FirebaseStorage.instance.ref().child('profile_pictures/$fileName');
    await ref.putBlob(image);

    final url = await ref.getDownloadURL();

    if (user != null) {
      return await FirebaseFirestore.instance
          .collection('users')
          .doc(user.email)
          .update({'profilePicture': url});
    }
  }
}

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
