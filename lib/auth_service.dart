import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

class AuthService {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  // final FirebaseFirestore _firestore;

  AuthService({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    FirebaseFirestore? firestore,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance;
       // _firestore = firestore ?? FirebaseFirestore.instance;

  /// Initializes Google Sign-In for non-web platforms with the provided serverClientId.
  void initializeGoogleSignIn(String serverClientId) {
    
    if (!kIsWeb) {
      // The serverClientId is only needed for the mobile flow to get an idToken.
      _googleSignIn.initialize(
        serverClientId: serverClientId
      );
    }
  }


  Future<void> sendSignInLinkToEmail({
    required String email,
    required String url, // The deep link URL that will open your app
    required String packageName, // Your Android package name
  }) async {
    debugPrint("Sending sign-in link to email: $email");
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
    required String email,
    required String link,
  }) async {
    try {
      if (_firebaseAuth.isSignInWithEmailLink(link)) {
        final UserCredential userCredential = await _firebaseAuth.signInWithEmailLink(
          email: email,
          emailLink: link,
        );
        // You can now access the signed-in user
        return userCredential.user;
      }
      return null;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  /// Handles the Google Sign-In flow for both web and mobile platforms.
  /// Returns the signed-in [User] on success, otherwise null.
  Future<User?> signInWithGoogle() async {
    debugPrint("Handling sign-in link: Google Sign-In");
    try {
      UserCredential userCredential;
      if (kIsWeb || kIsWasm) {
        GoogleAuthProvider googleAuthProvider = GoogleAuthProvider();
        userCredential = await FirebaseAuth.instance.signInWithPopup(googleAuthProvider);
      } else {
        _googleSignIn.initialize(
          serverClientId: "704034143445-acpce4ddkhnpl670pk1neueq8mmo69he.apps.googleusercontent.com"
        );
        final GoogleSignInAccount googleUser = await _googleSignIn.authenticate(
          scopeHint: ['email'],
        );
        final GoogleSignInAuthentication googleAuth = googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: null,
          idToken: googleAuth.idToken,
        );
        userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      }

      final user = userCredential.user;
      if (user != null) {
        if (userCredential.additionalUserInfo?.isNewUser == true) {
        }
      }
      return user;
    }
    catch (e) {
      return null;
    }
  }
}
