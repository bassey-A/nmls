import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final FirebaseFirestore _firestore;

  AuthService({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    FirebaseFirestore? firestore,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> sendSignInLinkToEmail({
    required String email,
    required String url, // The deep link URL that will open your app
    required String packageName, // Your Android package name
  }) async {
    try {
      var actionCodeSettings = ActionCodeSettings(
        url: url,
        handleCodeInApp: true,
        androidPackageName: packageName,
        androidInstallApp: true,
      );

      await _firebaseAuth.sendSignInLinkToEmail(
        email: email,
        actionCodeSettings: actionCodeSettings,
      );
      // IMPORTANT: You must save the user's email locally (e.g., using shared_preferences)
      // at this point. You will need it in Step 2 to complete the sign-in.
    } on FirebaseAuthException {
      // Re-throw the exception to be handled by the UI.
      rethrow;
    }
  }

  Future<User?> handleSignInLink({
    required String email, // The email you saved locally in Step 1
    required String link, // The link that opened your app
  }) async {
    try {
      if (_firebaseAuth.isSignInWithEmailLink(link)) {
        final UserCredential userCredential =
            await _firebaseAuth.signInWithEmailLink(
          email: email,
          emailLink: link,
        );

        final user = userCredential.user;
        if (user != null) {
          if (userCredential.additionalUserInfo?.isNewUser == true) {
            await _createNewStudent(user);
          }
        }
        return user;
      }
      return null;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  /// Handles the Google Sign-In flow for both web and mobile platforms.
  /// Returns the signed-in [User] on success, otherwise null.
  Future<User?> signInWithGoogle() async {
    try {
      UserCredential userCredential;

      if (kIsWeb) {
        GoogleAuthProvider googleAuthProvider = GoogleAuthProvider();
        userCredential =
            await _firebaseAuth.signInWithPopup(googleAuthProvider);
      } else {
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          // The user canceled the sign-in
          return null;
        }
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        userCredential = await _firebaseAuth.signInWithCredential(credential);
      }

      final user = userCredential.user;
      if (user != null) {
        if (userCredential.additionalUserInfo?.isNewUser == true) {
          await _createNewStudent(user);
        }
      }
      return user;
    } catch (e) {
      // Handle errors appropriately in your UI
      print('Error during Google Sign-In: $e');
      return null;
    }
  }

  /// Helper method to create a default student document for a new user.
  Future<void> _createNewStudent(User user) async {
    // MODIFIED: Use the user's UID as the document ID for consistency.
    final studentRef = _firestore.collection('students').doc(user.uid);
    // Check if the document already exists to avoid overwriting.
    final doc = await studentRef.get();
    if (!doc.exists) {
      await studentRef.set({
        'name': user.displayName ?? 'New Student',
        'email': user.email!,
        'programmeId': '', // Initially no programme
        'enrollmentSummary': {},
      });
    }
  }
}
