import 'package:flutter/foundation.dart';

class ApiConstants {
  static String baseUrl =
      kIsWeb
          ? 'http://localhost:3000' // Web Admin
          : 'http://10.0.2.2:3000'; // Android Emulator

  // Endpoint
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String users = '/users';
}
