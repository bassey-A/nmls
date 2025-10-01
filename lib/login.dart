// import 'package:flutter/material.dart';
// import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// import 'package:fluttertoast/fluttertoast.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'auth_service.dart';
// import 'package:provider/provider.dart';
// import 'app_config.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// class LoginPage extends StatefulWidget {
//   const LoginPage({super.key});

//   @override
//   State<LoginPage> createState() => _LoginPageState();
// }

// class _LoginPageState extends State<LoginPage> {
//   final AuthService _authService = AuthService();
//   final _emailController = TextEditingController();
//   bool _isLoading = false;

//   @override
//   void initState() {
//     super.initState();
//     final String serverClientId = Provider.of<AppConfig>(context, listen: false).serverClientId;
//     _authService.initializeGoogleSignIn(serverClientId);
//   }

//   @override
//   void dispose() {
//     _emailController.dispose();
//     super.dispose();
//   }

//   Future<void> _handleEmailLinkSignIn() async {
//     if (_isLoading || _emailController.text.trim().isEmpty) return;
//     setState(() => _isLoading = true);

//     try {
//       // --- MODIFIED: Use your whitelisted domain for the URL ---
//       // This URL must be added to your Firebase Console -> Authentication -> Authorized Domains
//       const yourDeepLinkUrl = "https://nlms-niger.firebaseapp.com";
//       const yourPackageName = "com.example.nmls";

//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setString('emailForSignIn', _emailController.text.trim());

//       await _authService.sendSignInLinkToEmail(
//         email: _emailController.text.trim(),
//         url: yourDeepLinkUrl,
//         packageName: yourPackageName,
//       );

//       if (mounted) {
//         Fluttertoast.showToast(
//           msg: "A sign-in link has been sent to your email.",
//           backgroundColor: Colors.green,
//           toastLength: Toast.LENGTH_LONG,
//         );
//         _emailController.clear();
//       }
//     } on FirebaseAuthException catch (e) {
//       String message = e.message ?? 'An error occurred.';
//       if (mounted) {
//         Fluttertoast.showToast(
//           msg: message,
//           backgroundColor: Colors.red,
//           toastLength: Toast.LENGTH_LONG,
//         );
//       }
//     } finally {
//       if (mounted) {
//         setState(() => _isLoading = false);
//       }
//     }
//   }

//   Future<void> _handleGoogleSignIn() async {
//     if (_isLoading) return;
//     setState(() => _isLoading = true);
//     try {
//       final user = await _authService.signInWithGoogle();
//       if (user != null && mounted) {
//         Navigator.pop(context);
//       }
//     } catch (e) {
//       if (mounted) {
//         Fluttertoast.showToast(
//           msg: "Google Sign-In failed. Please try again.",
//           backgroundColor: Colors.red,
//           toastLength: Toast.LENGTH_LONG,
//         );
//       }
//     } finally {
//       if (mounted) {
//         setState(() => _isLoading = false);
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final colorScheme = Theme.of(context).colorScheme;

//     return Container(
//       decoration: const BoxDecoration(
//         image: DecorationImage(
//           image: AssetImage('assets/images/bg.png'),
//           fit: BoxFit.cover,
//         ),
//       ),
//       child: Scaffold(
//         backgroundColor: Colors.transparent,
//         appBar: AppBar(
//           title: const Text(''),
//           backgroundColor: Colors.transparent,
//           elevation: 0,
//         ),
//         extendBodyBehindAppBar: true,
//         body: Stack(
//           children: <Widget>[
//             Container(color: Colors.black.withAlpha((255 * 0.4).round())),
//             if (_isLoading)
//               const Center(
//                 child: CircularProgressIndicator(),
//               ),
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16.0),
//               child: Center(
//                 child: SizedBox(
//                   width: 300,
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: <Widget>[
//                       const SizedBox(height: 20),
//                       TextField(
//                         controller: _emailController,
//                         keyboardType: TextInputType.emailAddress,
//                         style: const TextStyle(color: Colors.white),
//                         decoration: InputDecoration(
//                           labelText: 'Email',
//                           labelStyle: const TextStyle(color: Colors.white70),
//                           border: const OutlineInputBorder(),
//                           filled: true,
//                           fillColor: colorScheme.surface.withAlpha(100),
//                         ),
//                       ),
//                       const SizedBox(height: 20),
//                       ElevatedButton(
//                         style: ElevatedButton.styleFrom(
//                             minimumSize: const Size.fromHeight(50)),
//                         onPressed: _isLoading ? null : _handleEmailLinkSignIn,
//                         child: const Text('Send Sign-In Link'),
//                       ),
//                       const SizedBox(height: 20),
//                       const Text('Or sign in with',
//                           style: TextStyle(color: Colors.white70)),
//                       const SizedBox(height: 12),
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           IconButton(
//                             icon: const FaIcon(FontAwesomeIcons.google),
//                             color: Colors.white,
//                             onPressed: _isLoading ? null : _handleGoogleSignIn,
//                           ),
//                           const SizedBox(width: 25),
//                           IconButton(
//                             icon: const FaIcon(FontAwesomeIcons.apple),
//                             color: Colors.white,
//                             onPressed: _isLoading ? null : () {},
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService _authService = AuthService();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailLinkSignIn() async {
    if (_isLoading || _emailController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);

    try {
      const yourDeepLinkUrl = "https://nlms-niger.firebaseapp.com";
      const yourPackageName = "com.example.nmls";

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('emailForSignIn', _emailController.text.trim());

      await _authService.sendSignInLinkToEmail(
        email: _emailController.text.trim(),
        url: yourDeepLinkUrl,
        packageName: yourPackageName,
      );

      if (mounted) {
        Fluttertoast.showToast(
          msg: "A sign-in link has been sent to your email.",
          backgroundColor: Colors.green,
          toastLength: Toast.LENGTH_LONG,
        );
        _emailController.clear();
      }
    } on FirebaseAuthException catch (e) {
      String message = "Error: ${e.message ?? 'An unknown error occurred.'}";
      if (mounted) {
        Fluttertoast.showToast(
          msg: message,
          backgroundColor: Colors.red,
          toastLength: Toast.LENGTH_LONG,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final user = await _authService.signInWithGoogle();
      if (user != null && mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Google Sign-In Error: $e");
      if (mounted) {
        Fluttertoast.showToast(
          msg: "Google Sign-In Failed: ${e.toString()}",
          backgroundColor: Colors.red,
          toastLength: Toast.LENGTH_LONG,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/bg.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(''),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        extendBodyBehindAppBar: true,
        body: Stack(
          children: <Widget>[
            Container(color: Colors.black.withAlpha((255 * 0.4).round())),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: SizedBox(
                  width: 300,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const SizedBox(height: 20),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Email',
                          labelStyle: const TextStyle(color: Colors.white70),
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: colorScheme.surface.withAlpha(100),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50)),
                        onPressed: _isLoading ? null : () => _handleEmailLinkSignIn(),
                        child: const Text('Send Sign-In Link'),
                      ),
                      const SizedBox(height: 20),
                      const Text('Or sign in with',
                          style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const FaIcon(FontAwesomeIcons.google),
                            color: Colors.white,
                            onPressed: _isLoading ? null : _handleGoogleSignIn,
                          ),
                          const SizedBox(width: 25),
                          IconButton(
                            icon: const FaIcon(FontAwesomeIcons.apple),
                            color: Colors.white,
                            onPressed: _isLoading ? null : () {
                               Fluttertoast.showToast(msg: "Apple Sign-In is not yet implemented.");
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
