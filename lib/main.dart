import 'package:flutter/material.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:nmls/ad_service.dart';
import 'package:nmls/splash_screen.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'ad_service.dart';
import 'app_config.dart';
import 'user_service.dart';
import 'firebase_options.dart';
import 'notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  const String serverClientId = String.fromEnvironment('SERVER_CLIENT_ID');
  final appDocumentDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocumentDir.path);

    // HIVE SETUP: Register all your new adapters from user_service.dart
  Hive.registerAdapter(StudentAdapter());
  Hive.registerAdapter(LecturerAdapter());
  Hive.registerAdapter(SchoolAdminAdapter());
  Hive.registerAdapter(AcademicRecordAdapter());
  Hive.registerAdapter(LecturerCourseInfoAdapter());
  Hive.registerAdapter(AnnouncementInfoAdapter());

  // Open Hive boxes for user data caching
  await Hive.openBox<List>('academicRecords');
  await Hive.openBox<List>('classRosters');
  await Hive.openBox<List>('teachingLoad');
  await Hive.openBox<List>('announcements');
  await Hive.openBox<Map>('chartData');
  
  runApp(
    MultiProvider(
      providers: [
        Provider<AppConfig>(
          create: (_) => AppConfig(serverClientId: serverClientId),
        ),
        ChangeNotifierProvider<UserService>(
           create: (_) => UserService(),
        ),
        ChangeNotifierProvider<NotificationService>(
          create: (_) => NotificationService(),
        ),
        ChangeNotifierProvider(
          create: (_) => AdService(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color seedColor = Color.fromARGB(255, 6, 129, 230);

    final lightTheme = FlexColorScheme.light(
      primary: seedColor,
      keyColors: const FlexKeyColors(useKeyColors: true),
      variant: FlexSchemeVariant.expressive,
    ).toTheme;

    final darkTheme = FlexColorScheme.dark(
      primary: seedColor,
      primaryLightRef: seedColor,
      keyColors: const FlexKeyColors(useKeyColors: true),
      variant: FlexSchemeVariant.expressive,
    ).toTheme;

    return MaterialApp(
      title: 'School LMS',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system, 
      home: const SplashScreen(),
    );
  }
}
