// lib/splash_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'main_scaffold.dart';
import 'user_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await MobileAds.instance.initialize();
      RequestConfiguration configuration = RequestConfiguration(
        testDeviceIds: <String>['C74C99DB59C01DB757C8A10D25CF8106'], // The ID from your log
      );
      MobileAds.instance.updateRequestConfiguration(configuration);
    } catch (e) {
      debugPrint("MobileAds.instance.initialize() failed: $e");
    }
    final userService = Provider.of<UserService>(context, listen: false);
    
    // This function will wait until the 'isLoading' flag in UserService is false.
    await _waitForUserLoad(userService);
    
    // Once everything is loaded, navigate to the main scaffold
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainScaffold()),
      );
    }
  }

  // This helper function listens to the UserService and completes
  // only when the user's role has been determined.
  Future<void> _waitForUserLoad(UserService userService) {
    // If the user service is already done loading, we can continue immediately.
    if (!userService.isLoading) {
      return Future.value();
    }
    
    // Otherwise, listen for the next change and wait.
    final completer = Completer<void>();
    void listener() {
      if (!userService.isLoading) {
        // Stop listening and complete the future
        userService.removeListener(listener);
        completer.complete();
      }
    }
    userService.addListener(listener);
    return completer.future;
  }


  @override
  Widget build(BuildContext context) {
    // This is the simple UI shown to the user while the app loads.
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text("Initializing..."),
          ],
        ),
      ),
    );
  }
}
