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
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'notification_service.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;
  
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  final AuthService _authService = AuthService();
  
  bool _wasLoggedIn = false;
  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;

  @override
  void initState() {
    super.initState();
    _initAppLinks();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111', // change before deployment
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isBannerAdReady = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('BannerAd failed to load: $error');
        },
      ),
    )..load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userService = Provider.of<UserService>(context);
    final notificationService = Provider.of<NotificationService>(context, listen: false);

    final bool isLoggedIn = userService.user != null && !userService.isLoading;

    if (isLoggedIn != _wasLoggedIn) {
      if (isLoggedIn) {
        notificationService.startListening(userService);
      } else {
        notificationService.stopListening();
      }
      _wasLoggedIn = isLoggedIn;
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initAppLinks() async {
    _appLinks = AppLinks();
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      _handleDeepLink(initialUri);
    }
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  Future<void> _handleDeepLink(Uri uri) async {
    if (FirebaseAuth.instance.isSignInWithEmailLink(uri.toString())) {
      final prefs = await SharedPreferences.getInstance();
      final String? email = prefs.getString('emailForSignIn');

      if (email != null) {
        try {
          await _authService.handleSignInLink(
            email: email,
            link: uri.toString(),
          );
          await prefs.remove('emailForSignIn');
        } catch (e) {
          debugPrint("Error handling sign-in link: $e");
        }
      }
    }
  }

  static const List<Widget> _allPages = <Widget>[
    OverviewPage(),
    CalendarPage(),
    ToDoPage(),
    AnnouncementPage(),
    MessagesPage(),
    AboutTheSchoolPage(),
  ];

  void _onItemTapped(int index) {
    if (index == 3) {
      Provider.of<NotificationService>(context, listen: false).clearAnnouncementsCount();
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userService = Provider.of<UserService>(context);
    final user = userService.user;
    final bool isLoggedIn = user != null;

    if (!isLoggedIn) {
      return Scaffold(
        // backgroundColor: Colors.grey[200],
        appBar: AppBar(
          title: const Text('School LMS',
          style: TextStyle(color: Colors.green),
          ),
          centerTitle: true,
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onTertiary,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                );
              },
              child: const Text('Login', textScaler: TextScaler.linear(1.5),
              style: TextStyle(color: Colors.green),
              ),
            ),
          ],
        ),
        body: const AboutTheSchoolPage(),
      );
    }

    String getUserInitial(User user) {
      if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
        return user.displayName!.trim()[0].toUpperCase();
      }
      return 'U';
    }

    return Scaffold(
      //backgroundColor: Colors.grey[750],
      appBar: AppBar(
        title: const Text('School LMS'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'logout') {
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
                    ? Text(getUserInitial(user))
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: _allPages,
            ),
          ),
          // If the ad is ready, display it at the bottom
          if (_isBannerAdReady)
            Container(
              alignment: Alignment.center,
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            )
        ],
      ),
      bottomNavigationBar: Consumer<NotificationService>(
        builder: (context, notificationService, child) {
          return BottomNavigationBar(
            items: <BottomNavigationBarItem>[
              const BottomNavigationBarItem(
                icon: Icon(Icons.school),
                label: "Overview",
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.calendar_today),
                label: 'Calendar',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.list),
                label: 'To Do',
              ),
              BottomNavigationBarItem(
                icon: Badge(
                  label: Text('${notificationService.unreadAnnouncements}'),
                  isLabelVisible: notificationService.unreadAnnouncements > 0,
                  child: const Icon(Icons.announcement),
                ),
                label: 'Announce',
              ),
              BottomNavigationBarItem(
                icon: Badge(
                  label: Text('${notificationService.unreadMessages}'),
                  isLabelVisible: notificationService.unreadMessages > 0,
                  child: const Icon(Icons.message),
                ),
                label: 'Messages',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.info_outline),
                label: 'About',
              ),
            ],
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed,
          );
        },
      ),
    );
  }
}
