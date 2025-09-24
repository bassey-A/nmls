import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nmls/overview_view.dart';
import 'package:nmls/to_do_view.dart';
import 'package:provider/provider.dart';
import 'user_service.dart';
import 'login.dart';
import 'calendar_view.dart';
import 'about_the_school.dart';
import 'messages_view.dart';
import 'announcement_view.dart';
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;
  
  // --- NEW: Additions for App Links ---
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  final AuthService _authService = AuthService();
  // --- END NEW ---

  // --- NEW: initState to handle link listening ---
  @override
  void initState() {
    super.initState();
    _initAppLinks();
  }
  // --- END NEW ---

  // --- NEW: dispose to clean up the listener ---
  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }
  // --- END NEW ---


  // --- NEW: Method to initialize and listen for links ---
  Future<void> _initAppLinks() async {
    _appLinks = AppLinks();

    // Get the initial link that launched the app
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      _handleDeepLink(initialUri);
    }

    // Listen for new links when the app is already running
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }
  // --- END NEW ---

  // --- NEW: Method to process the link and sign the user in ---
  Future<void> _handleDeepLink(Uri uri) async {
    // Check if the link is an email sign-in link
    if (FirebaseAuth.instance.isSignInWithEmailLink(uri.toString())) {
      final prefs = await SharedPreferences.getInstance();
      final String? email = prefs.getString('emailForSignIn');

      if (email != null) {
        try {
          await _authService.handleSignInLink(
            email: email,
            link: uri.toString(),
          );
          // The user is now signed in. The onAuthStateChanged listener
          // in your UserService will handle any UI updates.
          await prefs.remove('emailForSignIn'); // Clean up stored email
        } catch (e) {
          debugPrint("Error handling sign-in link: $e");
          // Optionally show a toast or message to the user
        }
      }
    }
  }
  // --- END NEW ---


  // Define all possible pages and navigation items
  static const List<Widget> _allPages = <Widget>[
    OverviewPage(),
    CalendarPage(),
    ToDoPage(),
    AnnouncementPage(),
    MessagesPage(),
    AboutTheSchoolPage(),
  ];

  static const List<BottomNavigationBarItem> _allNavItems = <BottomNavigationBarItem>[
    BottomNavigationBarItem(
      icon: Icon(Icons.school),
      label: "Overview",
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.calendar_today),
      label: 'Calendar',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.list),
      label: 'To Do',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.announcement),
      label: 'Announce',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.message),
      label: 'Messages',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.school),
      label: 'About',
    ),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userService = Provider.of<UserService>(context);
    final user = userService.user;
    final bool isLoggedIn = user != null;

    // If the user is not logged in, show a simple scaffold with only the
    // "About" page and no BottomNavigationBar.
    if (!isLoggedIn) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('School LMS'), centerTitle: true,
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                );
              },
              child: const Text('Login', textScaler: TextScaler.linear(1.5),
              style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        body: const AboutTheSchoolPage(),
        // No BottomNavigationBar is rendered when not logged in.
      );
    }

    // If the user is logged in, build the full UI with the BottomNavigationBar.
    return Scaffold(
      appBar: AppBar(
        title: const Text('School LMS'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'logout') {
                  // Use the UserService to sign out
                  Provider.of<UserService>(context, listen: false).signOut();
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  enabled: false,
                  child: Text('Signed in as ${user.displayName ?? 'User'}'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Text('Logout'),
                ),
              ],
              child: CircleAvatar(
                backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                child: user.photoURL == null
                    ? Text(user.displayName?.split(' ')[0].toUpperCase() ?? 'U')
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _allPages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: _allNavItems,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}

