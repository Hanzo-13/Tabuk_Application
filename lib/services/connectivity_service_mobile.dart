// Mobile/desktop-specific connectivity check
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:capstone_app/utils/constants.dart';
import 'package:capstone_app/models/connectivity_info.dart';

Future<ConnectivityInfo> checkConnectionPlatform() async {
  final connectivityResult = await Connectivity().checkConnectivity();

  if (connectivityResult == ConnectivityResult.none) {
    return ConnectivityInfo(
      status: ConnectionStatus.noNetwork,
      connectionType: connectivityResult,
      message: AppConstants.connectivityNoNetwork,
    );
  }

  final hasRealInternet = await _testInternetAccess(connectivityResult);

  if (hasRealInternet) {
    return ConnectivityInfo(
      status: ConnectionStatus.connected,
      connectionType: connectivityResult,
      message: AppConstants.connectivityConnected,
    );
  } else {
    if (connectivityResult == ConnectivityResult.mobile) {
      return ConnectivityInfo(
        status: ConnectionStatus.mobileDataNoInternet,
        connectionType: connectivityResult,
        message: AppConstants.connectivityMobileNoInternet,
        isMobileDataWithoutInternet: true,
      );
    } else if (connectivityResult == ConnectivityResult.wifi) {
      return ConnectivityInfo(
        status: ConnectionStatus.noInternet,
        connectionType: connectivityResult,
        message: AppConstants.connectivityWifiNoInternet,
      );
    } else {
      return ConnectivityInfo(
        status: ConnectionStatus.noInternet,
        connectionType: connectivityResult,
        message: AppConstants.connectivityNetworkNoInternet,
      );
    }
  }
}

Future<bool> _testInternetAccess(ConnectivityResult connectionType) async {
  try {
    for (int attempt = 0; attempt < AppConstants.connectivityTestAttempts; attempt++) {
      const testUrls = [
        'google.com',
        '8.8.8.8',
        'cloudflare.com',
        '1.1.1.1',
        'facebook.com',
      ];
      for (String url in testUrls) {
        try {
          final result = await InternetAddress.lookup(url).timeout(
            const Duration(seconds: AppConstants.connectivityDnsTimeoutSeconds),
          );

          if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
            if (connectionType == ConnectivityResult.mobile) {
              return await _testHttpConnection();
            }
            return true;
          }
        } catch (_) {
          continue;
        }
      }

      if (attempt == 0) {
        await Future.delayed(
          const Duration(seconds: AppConstants.connectivityRetryDelaySeconds),
        );
      }
    }
    return false;
  } catch (_) {
    return false;
  }
}

Future<bool> _testHttpConnection() async {
  try {
    final httpClient = HttpClient();
    httpClient.connectionTimeout = const Duration(seconds: AppConstants.connectivityHttpTimeoutSeconds);

    final request = await httpClient.getUrl(
      Uri.parse(AppConstants.connectivityHttpTestUrl),
    );
    final response = await request.close().timeout(
      const Duration(seconds: AppConstants.connectivityHttpTimeoutSeconds),
    );

    httpClient.close();
    return response.statusCode == 200;
  } catch (_) {
    return false;
  }
}
