import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:studybeats/api/Graph/graph_api.dart';
import 'package:studybeats/api/analytics/analytics_service.dart';
import 'package:studybeats/api/auth/signup_method.dart';
import 'package:studybeats/app_state.dart';
import 'package:studybeats/log_printer.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';
import 'package:universal_html/html.dart' as html;
import 'package:uuid/uuid.dart';

class AuthService {
  final Logger _logger = getLogger('AuthService');
  final AnalyticsService _analyticsService = AnalyticsService();

  ///
  ///Gets the current Firebase user. Studybeats assumes that a user is always logged in
  /// if the user is not logged in, it will attempt to log in anonymously to create a user
  /// Ideally the user should already be logged in before this function is called
  Future<User> getCurrentUser({int retryCount = 3}) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      while (user == null && retryCount > 0) {
        _logger.w('Current user is null. Creating anonymous user');
        await logInAnonymously();
        user = FirebaseAuth.instance.currentUser;
        retryCount--;
      }

      if (user == null) {
        _logger.e('Failed to retrieve current user after retries');
        throw Exception('User is null after retries');
      }

      _logger.i('Current user retrieved: ${user.email ?? user.uid}');

      return user;
    } catch (e) {
      _logger.e('Error retrieving current user: $e');
      rethrow;
    }
  }

  /// Returns the Firestore document ID for the current Firebase user.
  /// User docs are stored by their email address, but for anonymous users,
  /// the UID is used instead.
  /// Falls back to the UID when `email` is null (e.g. anonymous accounts).
  String docIdForUser(User user) {
    if (user.isAnonymous) {
      return user.uid;
    } else {
      final email = user.email;
      if (email != null) {
        return email;
      } else {
        return user.uid;
      }
    }
  }

  Future<bool> isUserAnonymous() async {
    final user = await getCurrentUser();
    return user.isAnonymous;
  }

  Future<void> logInAnonymously() async {
    try {
      _logger.i('Attempting to log in anonymously');
      await FirebaseAuth.instance.signInAnonymously();
      // Look in firestore database to see if this user exists
      final user = await getCurrentUser();

      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(docIdForUser(user));

      final docSnapshot = await userRef.get();
      if (!docSnapshot.exists) {
        _logger.d('User document does not exist. Creating baseline record.');
        await _registerWithFirestore(
            'Anonymous User', null, SignupMethod.anonymous);
      }

      _analyticsService.logLogin();
      _logger.i('User logged in anonymously');
    } on FirebaseAuthException catch (e) {
      _logger.w('FIREBASE EXCEPTION: Anonymous login failed. $e');
      rethrow;
    } catch (e) {
      _logger.e('Anonymous login failed: $e');
      rethrow;
    }
  }

  Future _createUserEmailPassword(String email, String password) async {
    try {
      _logger.i('Requesting account creation with email and password');
      _analyticsService.logSignUp(SignupMethod.email);
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

  Future _registerWithFirestore(
      String name, String? imageURL, SignupMethod method) async {
    try {
      _logger.i('Registering user with Firebase');
      return await FirebaseFirestore.instance
          .collection('users')
          .doc(docIdForUser(await getCurrentUser()))
          .set({
        'uid': (await getCurrentUser()).uid,
        'profilePicture': imageURL,
        'name': name,
        'selectedSceneId': 1,
        'lastUsed': DateTime.now(),
        'usageCount': 1,
        'streakLength': 1,
        'numDaysUsed': 1,
        'loginMethod': method.name,
      });
    } catch (e) {
      _logger.e(e);
      rethrow;
    }
  }

  Future getCurrentUserEmail() async {
    final user = await getCurrentUser();
    return user.email;
  }

  Future<int> getselectedSceneId() async {
    final user = await getCurrentUser();
    final dataSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(docIdForUser(user))
        .get();

    if (!dataSnapshot.exists) {
      return 1;
    }

    if (dataSnapshot.data()!.containsKey('selectedSceneId')) {
      return dataSnapshot.get('selectedSceneId');
    } else {
      return 1;
    }
  }

  Future changeselectedSceneId(int index) async {
    final user = await getCurrentUser();
    await FirebaseFirestore.instance
        .collection('users')
        .doc(docIdForUser(user))
        .update({'selectedSceneId': index});
  }

  Future _login(String email, String password) async {
    try {
      _logger.i('Attempting to log user: $email');

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _analyticsService.logLogin();
    } on FirebaseAuthException catch (e) {
      _logger.w('FIREBASE EXCEPTION: Login with email/password failed. $e');
      rethrow;
    } catch (e) {
      _logger.e('Log in user with email/password failed: $e');
      rethrow;
    }
  }

  Future<void> signUp(String email, String password, String name) async {
    try {
      await _createUserEmailPassword(email, password);
      await _login(email, password);
      await _registerWithFirestore(name, null, SignupMethod.email);
      _logger.i('User registered succesfully');
    } catch (e) {
      rethrow;
    }
  }

  bool isUserLoggedIn() {
    return FirebaseAuth.instance.currentUser != null;
  }

  Future<void> signOutAndLoginAnonymously() async {
    try {
      _logger.i('Signing out user and logging in anonymously');
      await FirebaseAuth.instance.signOut();
      await logInAnonymously();
      _logger.i('User signed out and logged in anonymously');
    } catch (e) {
      _logger.e('Sign out and login anonymously failed: $e');
      rethrow;
    }
  }

  Future<void> signUpInWithGoogle() async {
    try {
      _logger.i('Attempting to sign in with Google');
      GoogleSignInAccount? googleUser = await googleSignIn.signInSilently();

      if (googleUser == null) {
        googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          _logger.e('Google user returned null');
          throw Exception();
        }
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      final user = await getCurrentUser();

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(docIdForUser(user))
          .get();
      if (!doc.exists) {
        await _analyticsService.logSignUp(SignupMethod.google);
        await _registerWithFirestore(
            user.displayName!, user.photoURL!, SignupMethod.google);
      }

      await _analyticsService.logLogin();
      _logger.i('User signed in with Google');
    } catch (e) {
      _logger.e('Google sign in failed. $e');
      rethrow;
    }
  }

  Future<UserMetadata> getUserMetadata() async {
    final user = await getCurrentUser();
    return user.metadata;
  }

  // Call this function to log the date time that the user last used the app
  Future<void> logUserUsage() async {
    try {
      final user = await getCurrentUser();

      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(docIdForUser(user));

      // Ensure the document exists before running the transaction
      final docSnapshot = await userRef.get();
      if (!docSnapshot.exists) {
        _logger.e('User document did not exist. Creating baseline record.');
        return;
      }

      // Atomic read‑modify‑write to keep stats accurate
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);

        // Existing values (with safe defaults)
        final data = snapshot.data() ?? {};
        final Timestamp? lastUsedTs = data['lastUsed'];
        final DateTime? prevLastUsed = lastUsedTs?.toDate();
        final int prevUsageCount = (data['usageCount'] ?? 0) as int;
        int streak = (data['streakLength'] ?? 1) as int;

        final DateTime now = DateTime.now();
        bool isSameDay(DateTime a, DateTime b) =>
            a.year == b.year && a.month == b.month && a.day == b.day;

        // Update streak logic
        if (prevLastUsed == null) {
          streak = 1;
        } else if (isSameDay(now, prevLastUsed)) {
          // Already counted today; streak unchanged
        } else if (isSameDay(
            now.subtract(const Duration(days: 1)), prevLastUsed)) {
          streak += 1; // consecutive day
        } else {
          streak = 1; // streak broken
        }

        // numDaysUsed logic
        int numDaysUsed = (data['numDaysUsed'] ?? 0) as int;
        bool countedToday =
            prevLastUsed != null && isSameDay(now, prevLastUsed);
        if (!countedToday) {
          numDaysUsed += 1;
        }

        transaction.update(userRef, {
          'lastUsed': now,
          'usageCount': prevUsageCount + 1,
          'streakLength': streak,
          'numDaysUsed': numDaysUsed,
        });
      });
    } catch (e) {
      _logger.e('Error while logging user usage $e');
      rethrow;
    }
  }

  Future<void> signUpInWithMicrosoft() async {
    _logger.i('Attempting to sign in with Microsoft');
    final microsoftProvider = MicrosoftAuthProvider();
    microsoftProvider.setCustomParameters({'tenant': 'common'});
    microsoftProvider.addScope('User.ReadWrite.All');

    String displayName = '';
    try {
      final result =
          await FirebaseAuth.instance.signInWithPopup(microsoftProvider);
      final credential = result.credential;

      final user = await getCurrentUser();

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(docIdForUser(user))
          .get();
      if (!doc.exists) {
        final graphAPIService =
            GraphAPIService(accessToken: credential?.accessToken);

        final userModel = await graphAPIService.fetchUserInfo();

        if (userModel.displayName == null) {
          _logger.e('Microsoft user display name came out as null');
          throw Exception();
        }

        displayName = userModel.displayName!;

        final bytes = await graphAPIService.fetchProfilePhoto();
        final image = MemoryImage(bytes);

        final ref = await _generateProfilePictureReference();

        await ref.putData(
            image.bytes, SettableMetadata(contentType: 'image/jpeg'));

        await _analyticsService.logSignUp(SignupMethod.microsoft);
        await _registerWithFirestore(
            displayName, await ref.getDownloadURL(), SignupMethod.microsoft);
      }

      await _analyticsService.logLogin();

      _logger.i('User signed in with Microsoft');
    } catch (e) {
      if (e is GraphAPIException) {
        _logger.w(
            'Profile photo request failed. Setting profile photo as default picture');
        await _analyticsService.logSignUp(SignupMethod.microsoft);
        await _registerWithFirestore(displayName, null, SignupMethod.microsoft);
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

  Future<String?> getProfilePictureUrl() async {
    try {
      final user = await getCurrentUser();
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(docIdForUser(user))
          .get();
      return doc.get('profilePicture');
    } catch (e) {
      throw Exception(e);
    }
  }

  Future<DateTime> getAccountCreationDate() async {
    final user = await getCurrentUser();
    return user.metadata.creationTime!;
  }

  Future<String> getCurrentUserUid() async {
    final user = await getCurrentUser();
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(docIdForUser(user))
          .get();
      return doc.get('uid');
    } catch (e) {
      _logger.e('Unknown error while retrieving uid $e');
      rethrow;
    }
  }

  Future<String> getDisplayName() async {
    final user = await getCurrentUser();
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(docIdForUser(user))
          .get();
      return doc.get('name');
    } catch (e) {
      _logger.e('Unknown error while retrieving user display name $e');
      rethrow;
    }
  }

  Future<void> updateProfilePicture(html.File image) async {
    // Delete the old profile picture if the domain is firebase storage
    _logger.i('Updating profile picture');
    final user = await getCurrentUser();
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(docIdForUser(user))
          .get();
      final oldProfilePicture = doc.get('profilePicture');
      if (oldProfilePicture.contains('firebasestorage.googleapis.com')) {
        _logger.i(
            'Profile picture found in firebasestorage domain. Deleting previous profile picture');
        final oldProfilePictureRef =
            FirebaseStorage.instance.refFromURL(oldProfilePicture);
        await oldProfilePictureRef.delete();
      }

      final ref = await _generateProfilePictureReference();
      print(ref);
      await ref.putBlob(image);

      final url = await ref.getDownloadURL();

      _logger.i('Profile picture uploaded to $url');

      await FirebaseFirestore.instance
          .collection('users')
          .doc(docIdForUser(user))
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

  Future<void> sendResetPasswordEmail(String email) async {
    _logger.i('Sending password reset email');
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } catch (e) {
      _logger.e('Password reset email failed. $e');
      rethrow;
    }
  }

  Future<void> sendEmailChangeEmail(String email) async {
    _logger.i('Sending email change email');
    try {
      final user = await getCurrentUser();
      await user.verifyBeforeUpdateEmail(email);
    } catch (e) {
      _logger.e('Email change failed. $e');
      rethrow;
    }
  }

  Future<void> changeName(String displayName) async {
    _logger.i('Changing display name');
    try {
      final user = await getCurrentUser();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.email)
          .update({'name': displayName});
    } catch (e) {
      _logger.e('Display name change failed. $e');
      rethrow;
    }
  }

  Future<int> getUsageCount() async {
    final user = await getCurrentUser();
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(docIdForUser(user))
        .get();
    return (doc.data()?['usageCount'] ?? 0) as int;
  }

  Future<int> getStreakLength() async {
    final user = await getCurrentUser();
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(docIdForUser(user))
        .get();
    return (doc.data()?['streakLength'] ?? 0) as int;
  }

  Future<int> getNumDaysUsed() async {
    final user = await getCurrentUser();
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(docIdForUser(user))
        .get();
    return (doc.data()?['numDaysUsed'] ?? 0) as int;
  }
}
