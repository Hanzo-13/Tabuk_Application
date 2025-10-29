// main.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:flutter/gestures.dart';
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
import 'package:capstone_app/widgets/responsive_wrapper.dart';

// Create a global Future that will hold the result of our initialization.
// This is done once and can be awaited in the UI.
final Future<void> appInitialization = _initializeApp();

// This function contains all the async work that needs to be done before the app is fully ready.
Future<void> _initializeApp() async {
  await AuthService.initializeAuthState();

  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
  } catch (_) {
    // Firestore persistence is not supported in all web environments.
    // We can safely ignore this error.
  }

  // Hive needs a different initialization path for web vs. mobile.
  if (kIsWeb) {
    await Hive.initFlutter();
  } else {
    final appDir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(appDir.path);
  }

  // Defer non-critical initializations until after the first frame to improve startup time.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!kIsWeb) {
      ImageCacheService.init();
    }
  });
}

// The main() function is now simple and safe for all platforms.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    // Use path-based URLs on web (removes the # from the URL).
    setUrlStrategy(PathUrlStrategy());
  }
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const TabukRoot());
}

// Your TabukRoot class and its State are UNCHANGED. They contain your connectivity logic.
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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConstants.appName,
      scrollBehavior: const _AppScrollBehavior(),
      builder: (context, child) => ResponsiveWrapper(child: child),
      home: const AuthChecker(),
    );
  }
}

// AuthChecker now waits for the initialization to finish before checking the auth state.
class AuthChecker extends StatelessWidget {
  const AuthChecker({super.key});

  @override
  Widget build(BuildContext context) {
    // Use a FutureBuilder to wait for our appInitialization to complete.
    return FutureBuilder(
      future: appInitialization,
      builder: (context, snapshot) {
        // While initializing, show a splash/loading screen.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        // If initialization fails, show an error message.
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text("Error initializing app: ${snapshot.error}"),
            ),
          );
        }

        // Once initialization is complete, proceed with your original authentication logic.
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
                  FirebaseFirestore.instance.collection('Users').doc(user.uid).get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingScreen();
                }
                if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
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
      },
    );
  }
}

// Your other classes (_RedirectByRole, LoadingScreen, _AppScrollBehavior) are UNCHANGED.
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

class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}