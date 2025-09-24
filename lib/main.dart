import 'package:flutter/material.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app_config.dart';
import 'user_service.dart';
import 'main_scaffold.dart';
import 'firebase_options.dart';

Future<void> main() async {
  // Ensure Flutter framework is initialized before running the app
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Google Mobile Ads SDK
  try {
    await MobileAds.instance.initialize();
  } catch (e) {
    debugPrint("MobileAds.instance.initialize() failed: $e");
  }

  // Initialize Firebase using the generated options file
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  const String serverClientId = String.fromEnvironment('SERVER_CLIENT_ID');
  
  runApp(
    // Use MultiProvider to make services available throughout the widget tree
    MultiProvider(
      providers: [
        Provider<AppConfig>(
          create: (_) => AppConfig(serverClientId: serverClientId),
        ),
        ChangeNotifierProvider<UserService>(
           create: (_) => UserService(),
        ),
      ],
      child: const MyApp(), // The root widget of the application
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // The seed color is the primary color from the deepBlue FlexScheme.
    const Color seedColor = Color.fromARGB(255, 0, 153, 51);

    // Define the light theme using FlexColorScheme.light with seeding enabled.
    // The seed color is passed via the `primary` property, and seeding is
    // activated with `keyColors`.
    final lightTheme = FlexColorScheme.light(
      primary: seedColor,
      keyColors: const FlexKeyColors(useKeyColors: true),
      variant: FlexSchemeVariant.expressive,
    ).toTheme;

    // Define the dark theme using the same seed and variant for consistency.
    // We pass the seedColor to `primary` and `primaryLightRef` to ensure the
    // generated dark theme uses the same tonal palette as the light theme.
    final darkTheme = FlexColorScheme.dark(
      primary: seedColor,
      primaryLightRef: seedColor,
      keyColors: const FlexKeyColors(useKeyColors: true),
      variant: FlexSchemeVariant.expressive,
    ).toTheme;

    return MaterialApp(
      title: 'School LMS',
      // Assign the created themes to the MaterialApp
      theme: lightTheme,
      darkTheme: darkTheme,
      // Automatically select the theme based on the device's system settings
      themeMode: ThemeMode.system, 
      home: const MainScaffold(),
    );
  }
}

