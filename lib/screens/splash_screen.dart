// ===========================================
// lib/screens/splash_screen.dart
// ===========================================

// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:capstone_app/models/connectivity_info.dart';
import 'package:capstone_app/services/auth_service.dart';
import 'package:capstone_app/services/connectivity_service.dart';
import 'package:capstone_app/services/session_services.dart';
import 'package:capstone_app/utils/colors.dart';
import 'package:capstone_app/utils/constants.dart';
import 'package:capstone_app/utils/navigation_helper.dart';
import 'package:capstone_app/widgets/app_logo_widget.dart';
import 'package:capstone_app/widgets/connectivity_widget.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final ConnectivityService _connectivityService = ConnectivityService();
  StreamSubscription<ConnectivityInfo>? _connectivitySubscription;
  ConnectivityInfo _currentConnectivityInfo = ConnectivityInfo(
    status: ConnectionStatus.checking,
    connectionType: ConnectivityResult.none,
    message: AppConstants.connectivityChecking,
  );

  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _startConnectivityMonitoring();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivityService.stopMonitoring();
    super.dispose();
  }

  void _startConnectivityMonitoring() {
    _connectivitySubscription =
        _connectivityService.connectivityStream.listen(_handleConnectivityChange);
    _connectivityService.startMonitoring();
  }

  void _handleConnectivityChange(ConnectivityInfo info) {
    if (!mounted) return;
    setState(() {
      _currentConnectivityInfo = info;
    });

    debugPrint('[SplashScreen] Connectivity status: ${info.status}');

    if (info.status == ConnectionStatus.connected && !_isNavigating) {
      debugPrint('[SplashScreen] Connected. Proceeding to session check...');
      _proceedAfterConnection();
    }
  }

  void _retryConnection() {
    _connectivityService.checkConnection();
  }

  Future<void> _proceedAfterConnection() async {
    setState(() => _isNavigating = true);
    await Future.delayed(const Duration(seconds: 1)); // allow animations to complete

    try {
      final session = await SessionService.getSession().timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );

      debugPrint('[SplashScreen] Retrieved session: $session');

      final isAuthenticated = await AuthService.isUserAuthenticated().timeout(
        const Duration(seconds: 5),
        onTimeout: () => false,
      );

      debugPrint('[SplashScreen] Firebase authenticated: $isAuthenticated');

      if (!mounted) return;

      if (session != null && isAuthenticated) {
        debugPrint('[SplashScreen] Authenticated. Redirecting to home...');
        // Use NavigationHelper to route based on user role
        final userRole = session['role'] ?? 'tourist';
        NavigationHelper.navigateBasedOnRole(context, userRole);
      } else {
        debugPrint('[SplashScreen] No session or auth. Redirecting to login...');
        await SessionService.clearSession();
        Navigator.pushReplacementNamed(context, AppConstants.loginRoute);
      }
    } catch (e) {
      debugPrint('[SplashScreen] ERROR during splash logic: $e');
      if (!mounted) return;

      // Fallback: force to login on any error
      await SessionService.clearSession();
      Navigator.pushReplacementNamed(context, AppConstants.loginRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AppLogoWidget(),
                  const SizedBox(height: AppConstants.splashLogoSpacing),

                  if (_currentConnectivityInfo.status != ConnectionStatus.checking) ...[
                    ConnectivityStatusIndicator(connectivityInfo: _currentConnectivityInfo),
                    const SizedBox(height: AppConstants.splashStatusSpacing),
                  ],

                  if (_currentConnectivityInfo.isMobileDataWithoutInternet &&
                      _currentConnectivityInfo.status != ConnectionStatus.checking) ...[
                    const MobileDataWarningCard(),
                    const SizedBox(height: AppConstants.splashWarningSpacing),
                  ],

                  ConnectivityActionButton(
                    connectivityInfo: _currentConnectivityInfo,
                    onRetry: _retryConnection,
                    isNavigating: _isNavigating,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
