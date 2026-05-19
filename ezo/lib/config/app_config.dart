import 'dart:io';
import 'package:flutter/foundation.dart';

class AppConfig {
  // API Configuration
  static String get apiBaseUrl {
    // If we're in development mode (e.g., flutter run), use localhost
    if (kDebugMode) {
      if (kIsWeb) {
        // return 'http://localhost:5004/';
        return 'https://flutterbackend.aeropackpos.in/';
      }
      try {
        if (Platform.isAndroid) {
          // 10.0.2.2 is the special alias to your host loopback interface in Android emulator
          // return 'http://10.0.2.2:5004/';
          return 'https://flutterbackend.aeropackpos.in/';
        }
      } on Object catch (_) {}

      // For real devices or desktop, localhost or host IP
      // Using 192.168.10.35 as a common local IP detected in the environment
      // return 'http://localhost:5004/'   ;
      return 'https://flutterbackend.aeropackpos.in/';
    }

    // Production URL
    // return 'http://localhost:5004/';
    return 'https://flutterbackend.aeropackpos.in/';
  }

  static const String apiVersion = 'v1';

  // Feature Flags
  static const bool enableSync = true;
  static const bool enableOfflineMode = true;
  static const bool enableBackup = true;

  // Environment
  static const String environment = String.fromEnvironment(
    'ENV',
    defaultValue: 'development',
  );

  static bool get isProduction => environment == 'production';
  static bool get isDevelopment => environment == 'development';
}
