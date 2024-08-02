import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flourish_web/api/graph_api.dart';
import 'package:flourish_web/app_state.dart';
import 'package:flourish_web/log_printer.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';
import 'package:universal_html/html.dart' as html;
import 'package:uuid/uuid.dart';
import 'urls.dart';

class AuthService {
  final Logger _logger = getLogger('AuthService');

  Future _createUserEmailPassword(String email, String password) async {
    try {
      _logger.i('Requesting account creation with email and password');
      return await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      // This error should not trigger because email password validation should have been done already by Email and Password Validator classes
      _logger
          .w('FIREBASE EXCEPTION: Create user with email/password failed. $e');
      rethrow;
    } catch (e) {
      _logger.e('Create user with email/password failed: $e');
      rethrow;
    }
  }

  Future _registerWithFirestore(String imageURL) async {
    try {
      _logger.i('Registering user with Firebase');
      return await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.email)
          .set({
        'uid': FirebaseAuth.instance.currentUser!.uid,
        'profilePicture': imageURL,
      });
    } catch (e) {
      _logger.e(e);
      rethrow;
    }
  }

  Future _login(String email, String password) async {
    try {
      _logger.i('Attempting to log user: $email');
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      _logger.w('FIREBASE EXCEPTION: Login with email/password failed. $e');
      rethrow;
    } catch (e) {
      _logger.e('Log in user with email/password failed: $e');
      rethrow;
    }
  }

  Future<void> signUp(String email, String password) async {
    try {
      await _createUserEmailPassword(email, password);
      await _login(email, password);
      await _registerWithFirestore(kDefaultProfilePicture);
      _logger.i('User registered succesfully');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signUpInWithGoogle() async {
    try {
      _logger.i('Attempting to sign in with Google');
      final GoogleSignInAccount? googleUser =
          await googleSignIn.signInSilently();

      if (googleUser == null) {
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          _logger.e('Google user returned null');
          throw Exception();
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
      } else {
        _logger.e('User is null after attempted Google Sign In');
        throw Exception();
      }
      _logger.i('User signed in with Google');
    } catch (e) {
      _logger.e('Google sign in failed. $e');
      rethrow;
    }
  }

  Future<void> signUpInWithMicrosoft() async {
    _logger.i('Attempting to sign in with Microsoft');
    final microsoftProvider = MicrosoftAuthProvider();
    microsoftProvider.setCustomParameters({'tenant': 'common'});
    microsoftProvider.addScope('User.ReadWrite.All');

    try {
      final result =
          await FirebaseAuth.instance.signInWithPopup(microsoftProvider);
      final credential = result.credential;

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.email)
            .get();
        if (!doc.exists) {
          final graphAPIService =
              GraphAPIService(accessToken: credential?.accessToken);

          final bytes = await graphAPIService.fetchProfilePhoto();
          final image = MemoryImage(bytes);

          final ref = await _generateProfilePictureReference();

          await ref.putData(
              image.bytes, SettableMetadata(contentType: 'image/jpeg'));

          _registerWithFirestore(await ref.getDownloadURL());
        }
      } else {
        _logger.e('User is null after attempted Microsoft Sign In');
        throw Exception();
      }
      _logger.i('User signed in with Microsoft');
    } catch (e) {
      if (e is GraphAPIException) {
        _logger.w(
            'Profile photo request failed. Setting profile photo as default picture');
        _registerWithFirestore(kDefaultProfilePicture);
        return;
      }
      _logger.e('Microsoft sign in failed. $e');
      rethrow;
    }
  }

  Future signIn(String email, String password) async {
    try {
      await _login(email, password);
    } catch (e) {
      _logger.e('Sign in for $email failed. $e');
      rethrow;
    }
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
        _logger.e('Profile picture url access attempted while logged out');
        throw Exception();
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
      _logger.e('Attempted to get account creation date while logged out');
      throw Exception();
    }
  }

  Future<void> updateProfilePicture(html.File image) async {
    // Delete the old profile picture if the domain is firebase storage
    _logger.i('Updating profile picture');
    final user = FirebaseAuth.instance.currentUser;

    try {
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.email)
            .get();
        final oldProfilePicture = doc.get('profilePicture');
        if (oldProfilePicture.contains('firebasestorage.googleapis.com')) {
          _logger.i(
              'Profile picture found in firebasestorage domain. Deleting previous profile picture');
          final oldProfilePictureRef =
              FirebaseStorage.instance.refFromURL(oldProfilePicture);
          await oldProfilePictureRef.delete();
        }
      } else {
        _logger.e('User is null while updating profile picture');
        throw Exception();
      }

      final ref = await _generateProfilePictureReference();
      await ref.putBlob(image);

      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.email)
          .update({'profilePicture': url});
      _logger.i('Profile picture updated');
    } catch (e) {
      _logger.e('Unknown error while updating profile photo');
      rethrow;
    }
  }

  Future<Reference> _generateProfilePictureReference() async {
    final fileName = const Uuid().v4();
    _logger.i('Generating profile picture reference. Uuid: $fileName');
    return FirebaseStorage.instance.ref().child('profile_pictures/$fileName');
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
