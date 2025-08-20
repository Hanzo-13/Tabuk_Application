// main.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:async';
// import 'package:capstone_app/models/destination_model.dart';
// import 'package:capstone_app/services/cache_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:capstone_app/services/auth_service.dart';
import 'package:capstone_app/services/image_cache_service.dart';
import 'package:capstone_app/services/connectivity_service.dart';
import 'package:capstone_app/models/connectivity_info.dart';
import 'package:capstone_app/utils/constants.dart';
import 'package:capstone_app/utils/navigation_helper.dart';
import 'package:capstone_app/screens/login_screen.dart';
import 'package:capstone_app/screens/splash_screen.dart';
import 'package:capstone_app/screens/tourist/main_tourist_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AuthService.initializeAuthState();
  // await Hive.initFlutter();
  // Hive.registerAdapter(HotspotAdapter());

  // await DestinationCacheService.init();
  // runApp(TabukRoot());

  final appDir = await getApplicationDocumentsDirectory();
  // final fetched = await FirebaseFirestore.instance.collection('destination').get();
  // final hotspots = fetched.docs.map((doc) => Hotspot.fromMap(doc.data(), doc.id)).toList();
  // await DestinationCacheService.cacheDestinations(hotspots);

  await Hive.initFlutter(appDir.path);
  // Defer heavy image cache initialization until after first frame to reduce jank
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ImageCacheService.init();
  });

  runApp(const TabukRoot());
}

class TabukRoot extends StatefulWidget {
  const TabukRoot({super.key});
  @override
  State<TabukRoot> createState() => _TabukRootState();
}

class _TabukRootState extends State<TabukRoot> with WidgetsBindingObserver {
  final ConnectivityService _connectivityService = ConnectivityService();
  late final StreamSubscription<ConnectivityInfo> _connectivitySubscription;
  bool _isAppInForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startConnectivityMonitoring();
  }

  void _startConnectivityMonitoring() {
    _connectivitySubscription = _connectivityService.connectivityStream.listen(
      _handleConnectivityChange,
      onError: (e) => debugPrint('Connectivity error: $e'),
    );
    _connectivityService.startMonitoring();
  }

  void _handleConnectivityChange(ConnectivityInfo info) {
    if (!_isAppInForeground || info.status == ConnectionStatus.connected) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (route) => false,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppInForeground = state == AppLifecycleState.resumed;
    if (_isAppInForeground) {
      _connectivityService.checkConnection();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription.cancel();
    _connectivityService.stopMonitoring();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConstants.appName,
      home: AuthChecker(),
    );
  }
}

class AuthChecker extends StatelessWidget {
  const AuthChecker({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        if (user == null) return const LoginScreen();
        if (user.isAnonymous) return const MainTouristScreen();
        if (!user.emailVerified) return const LoginScreen();

        return FutureBuilder<DocumentSnapshot>(
          future:
              FirebaseFirestore.instance
                  .collection('Users')
                  .doc(user.uid)
                  .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingScreen();
            }
            if (snapshot.hasError ||
                !snapshot.hasData ||
                !snapshot.data!.exists) {
              // If user doc missing or error, redirect to LoginScreen or another default screen
              return const LoginScreen();
            }

            final data = snapshot.data!.data() as Map<String, dynamic>;
            final role = data['role']?.toString() ?? '';
            final formCompleted = data['form_completed'] == true;

            if (role.isEmpty) return const LoginScreen();
            if (!formCompleted) return const LoginScreen();

            return _RedirectByRole(role: role);
          },
        );
      },
    );
  }
}

class _RedirectByRole extends StatefulWidget {
  final String role;
  const _RedirectByRole({required this.role});
  @override
  State<_RedirectByRole> createState() => _RedirectByRoleState();
}

class _RedirectByRoleState extends State<_RedirectByRole> {
  bool _navigated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_navigated) {
      _navigated = true;
      Future.microtask(() {
        NavigationHelper.navigateBasedOnRole(context, widget.role);
      });
    }
  }
  
  @override
  Widget build(BuildContext context) => const LoadingScreen();
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
