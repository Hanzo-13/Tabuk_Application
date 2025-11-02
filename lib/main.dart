// main.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:capstone_app/services/auth_service.dart';
import 'package:capstone_app/services/image_cache_service.dart';
import 'package:capstone_app/services/connectivity_service.dart';
import 'package:capstone_app/services/offline_data_service.dart';
import 'package:capstone_app/services/offline_sync_service.dart';
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
  // All the async work from your original main() function is moved here.
  await AuthService.initializeAuthState();

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  final appDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDir.path);
  
  // Initialize offline data service
  try {
    await OfflineDataService.initialize();
    
    // Auto-sync data in background if needed (non-blocking)
    // This will sync if data is older than 24 hours
    Future.microtask(() async {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && !user.isAnonymous) {
          // Check if sync is needed
          final needsSync = OfflineSyncService.shouldSync(
            maxAge: const Duration(hours: 24),
            userId: user.uid,
          );
          
          if (needsSync) {
            // Check connectivity before syncing
            final connectivityService = ConnectivityService();
            final connectivity = await connectivityService.checkConnection();
            
            if (connectivity.isConnected) {
              // Sync in background (without UI progress)
              await OfflineSyncService.syncAllData(
                userId: user.uid,
                downloadImages: false, // Skip images for auto-sync to save bandwidth
              );
              debugPrint('Background sync completed');
            }
          }
        }
      } catch (e) {
        debugPrint('Error during background sync: $e');
      }
    });
  } catch (e) {
    debugPrint('Error initializing offline data service: $e');
  }
  
  // This can still be deferred until after the first frame for performance.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!kIsWeb) {
      ImageCacheService.init();
    }
  });
}

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp(
//     options: DefaultFirebaseOptions.currentPlatform
//   );

//   await AuthService.initializeAuthState();

//   FirebaseFirestore.instance.settings = const Settings(
//     persistenceEnabled: true,
//   );

//   final appDir = await getApplicationDocumentsDirectory();
//   // final fetched = await FirebaseFirestore.instance.collection('destination').get();
//   // final hotspots = fetched.docs.map((doc) => Hotspot.fromMap(doc.data(), doc.id)).toList();
//   // await DestinationCacheService.cacheDestinations(hotspots);

//   await Hive.initFlutter(appDir.path);
//   // Defer heavy image cache initialization until after first frame to reduce jank
//   WidgetsBinding.instance.addPostFrameCallback((_) {
//     ImageCacheService.init();
//   });

//   runApp(const TabukRoot());
// }

void main() async {
  // --- Your main() function is now clean and safe ---
  WidgetsFlutterBinding.ensureInitialized();
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

  // @override
  // Widget build(BuildContext context) {
  //   return StreamBuilder<User?>(
  //     stream: FirebaseAuth.instance.authStateChanges(),
  //     builder: (context, snapshot) {
  //       final user = snapshot.data;

  //       if (snapshot.connectionState == ConnectionState.waiting) {
  //         return const SplashScreen();
  //       }

  //       if (user == null) return const LoginScreen();
  //       if (user.isAnonymous) return const MainTouristScreen();
  //       if (!user.emailVerified) return const LoginScreen();

  //       return FutureBuilder<DocumentSnapshot>(
  //         future:
  //             FirebaseFirestore.instance
  //                 .collection('Users')
  //                 .doc(user.uid)
  //                 .get(),
  //         builder: (context, snapshot) {
  //           if (snapshot.connectionState == ConnectionState.waiting) {
  //             return const LoadingScreen();
  //           }
  //           if (snapshot.hasError ||
  //               !snapshot.hasData ||
  //               !snapshot.data!.exists) {
  //             // If user doc missing or error, redirect to LoginScreen or another default screen
  //             return const LoginScreen();
  //           }

  //           final data = snapshot.data!.data() as Map<String, dynamic>;
  //           final role = data['role']?.toString() ?? '';
  //           final formCompleted = data['form_completed'] == true;

  //           if (role.isEmpty) return const LoginScreen();
  //           if (!formCompleted) return const LoginScreen();

  //           return _RedirectByRole(role: role);
  //         },
  //       );
  //     },
  //   );
  // }
  @override
  Widget build(BuildContext context) {
    // We wrap the StreamBuilder with a FutureBuilder that waits on our
    // appInitialization future from above.
    return FutureBuilder(
      future: appInitialization,
      builder: (context, snapshot) {
        // While initialization is running, show the splash screen.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        // If initialization fails (optional but good practice), show an error.
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text("Error initializing app: ${snapshot.error}"),
            ),
          );
        }

        // Once initialization is complete, proceed with your original auth logic.
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            final user = snapshot.data;

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SplashScreen();
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SplashScreen();
            }

            if (user == null) return const LoginScreen();
            if (user.isAnonymous) return const MainTouristScreen();
            // Your logic for emailVerified was a bit different, let's keep it
            if (!user.emailVerified && !user.isAnonymous) return const LoginScreen();

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('Users').doc(user.uid).get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingScreen();
                }
                if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                  return const LoginScreen();
                }

                final data = snapshot.data!.data() as Map<String, dynamic>;
                final role = data['role']?.toString() ?? '';
                // Your original logic had form_completed, let's keep that.
                final formCompleted = data['form_completed'] == true;

                if (role.isEmpty) return const LoginScreen();
                if (!formCompleted) return const LoginScreen();
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