// main.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/gestures.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
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

Future<void> _initializeApp() async {
  // OPTIMIZED: Split initialization to prevent blocking main thread
  // Critical operations first, then defer non-critical ones
  
  // 1. Initialize auth state (required for app to function)
  await AuthService.initializeAuthState();

  // 2. Configure Firestore (non-blocking, can fail gracefully)
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
  } catch (e) {
    // Firestore persistence is not supported in all web environments.
    // We can safely ignore this error.
    if (kDebugMode) debugPrint('Firestore persistence error (non-critical): $e');
  }

  // 3. Initialize Hive (can be deferred but needed early)
  // Run in parallel with other non-critical operations
  try {
    if (kIsWeb) {
      await Hive.initFlutter();
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      await Hive.initFlutter(appDir.path);
    }
  } catch (e) {
    if (kDebugMode) debugPrint('Hive initialization error: $e');
    // Continue even if Hive fails - app can work without it
  }
  
  // 4. Defer image cache initialization to avoid blocking
  // This is non-critical and can happen after first frame
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!kIsWeb) {
      // Run asynchronously to avoid blocking
      Future.microtask(() {
        try {
          ImageCacheService.init();
        } catch (e) {
          if (kDebugMode) debugPrint('Image cache init error: $e');
        }
      });
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

            // Reload user to get latest auth state (important for email verification)
            return FutureBuilder<User>(
              future: user.reload().then((_) => FirebaseAuth.instance.currentUser!).catchError((e) {
                debugPrint('Error reloading user: $e');
                return user; // Return original user if reload fails
              }),
              builder: (context, reloadSnapshot) {
                if (reloadSnapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingScreen();
                }

                final refreshedUser = reloadSnapshot.data ?? user;

                // Check email verification - first from Firebase Auth, then from Firestore as fallback
                return FutureBuilder<DocumentSnapshot?>(
                  future: () async {
                    try {
                      return await FirebaseFirestore.instance
                          .collection('Users')
                          .doc(refreshedUser.uid)
                          .get()
                          .timeout(const Duration(seconds: 10));
                    } on TimeoutException catch (e) {
                      // If Firestore times out, try to use cached data
                      debugPrint('Firestore fetch timeout - trying cached data: $e');
                      try {
                        return await FirebaseFirestore.instance
                            .collection('Users')
                            .doc(refreshedUser.uid)
                            .get(const GetOptions(source: Source.cache));
                      } catch (cacheError) {
                        debugPrint('Error fetching cached document: $cacheError');
                        rethrow;
                      }
                    } catch (e) {
                      debugPrint('Error fetching user document: $e');
                      // Try to use cached data as fallback
                      try {
                        return await FirebaseFirestore.instance
                            .collection('Users')
                            .doc(refreshedUser.uid)
                            .get(const GetOptions(source: Source.cache));
                      } catch (cacheError) {
                        debugPrint('Error fetching cached document: $cacheError');
                        rethrow;
                      }
                    }
                  }(),
                  builder: (context, docSnapshot) {
                    if (docSnapshot.connectionState == ConnectionState.waiting) {
                      return const LoadingScreen();
                    }

                    // Handle document errors more gracefully
                    if (docSnapshot.hasError) {
                      debugPrint('Error fetching user document (non-critical): ${docSnapshot.error}');
                      // Don't log out immediately - could be a network issue
                      // Show loading and retry
                      return const LoadingScreen();
                    }

                    // Check if document exists
                    if (!docSnapshot.hasData || docSnapshot.data == null || !docSnapshot.data!.exists) {
                      // If email is verified in Firebase Auth, allow through (document might be missing temporarily)
                      if (refreshedUser.emailVerified) {
                        debugPrint('User document missing but email verified - showing loading');
                        return const LoadingScreen();
                      }
                      debugPrint('User document does not exist - redirecting to login');
                      return const LoginScreen();
                    }

                    final userData = docSnapshot.data!.data() as Map<String, dynamic>?;
                    if (userData == null) {
                      debugPrint('User document data is null - redirecting to login');
                      return const LoginScreen();
                    }

                    // Check email verification with fallback to Firestore
                    bool isEmailVerified = refreshedUser.emailVerified;
                    
                    // Use Firestore app_email_verified as fallback
                    final appEmailVerified = userData['app_email_verified'] ?? false;
                    if (!isEmailVerified && appEmailVerified == true) {
                      isEmailVerified = true;
                      debugPrint('Using app_email_verified from Firestore as fallback');
                    }
                    
                    // For Google users, emails are pre-verified
                    if (!isEmailVerified && refreshedUser.providerData.any((info) => info.providerId == 'google.com')) {
                      isEmailVerified = true;
                      debugPrint('Google user detected - email considered verified');
                    }

                    // If still not verified, require verification
                    if (!isEmailVerified) {
                      debugPrint('User email not verified - redirecting to login');
                      return const LoginScreen();
                    }

                    final role = userData['role']?.toString() ?? '';
                    final formCompleted = userData['form_completed'] == true;

                    if (role.isEmpty) {
                      debugPrint('User role is empty - redirecting to login');
                      return const LoginScreen();
                    }
                    if (!formCompleted) {
                      debugPrint('User form not completed - redirecting to login');
                      return const LoginScreen();
                    }

                    return _RedirectByRole(role: role);
                  },
                );
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