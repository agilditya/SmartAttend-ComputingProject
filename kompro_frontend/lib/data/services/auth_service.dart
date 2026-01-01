import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  // --- KONFIGURASI URL ---
  static String get _baseUrl {
    if (kIsWeb) return 'http://localhost:3000';
    if (Platform.isAndroid) return 'http://10.0.2.2:3000';
    return 'http://localhost:3000';
  }

  final String _userUrl = '$_baseUrl/user';
  final String _adminUrl = '$_baseUrl/admin';

  // Inisialisasi Dio dengan konfigurasi timeout dan header default
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 3),
      contentType: 'application/json',
    ),
  );

  // ---------------------------------------------------------------------------
  // USER
  // ---------------------------------------------------------------------------

  /// Login
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _dio.post(
        '$_userUrl/login',
        data: {"email": email, "password": password},
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Verifikasi kode OTP/2FA
  Future<Map<String, dynamic>> verifyOtp(int userId, String code) async {
    try {
      final response = await _dio.post(
        '$_userUrl/verify-2fa',
        data: {"userId": userId, "code": code},
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// pengiriman ulang kode OTP ke email pengguna
  Future<void> resendOtp(int userId) async {
    try {
      await _dio.post('$_userUrl/resend-2fa', data: {"userId": userId});
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Memperbarui kata sandi pengguna dari menu profil
  Future<Map<String, dynamic>> updatePassword({
    required int userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _dio.post(
        '$_userUrl/update-password',
        data: {
          "userId": userId,
          "currentPassword": currentPassword,
          "newPassword": newPassword,
        },
      );
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Mengambil detail informasi profil pengguna
  Future<Map<String, dynamic>> getUserProfile(int userId) async {
    try {
      final response = await _dio.post(
        '$_userUrl/get-user',
        data: {"userId": userId},
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Mengambil daftar riwayat presensi milik pengguna tertentu
  Future<List<dynamic>> getAttendance(int userId) async {
    try {
      final response = await _dio.post(
        '$_userUrl/get-attendance-user',
        data: {"userId": userId},
      );
      return response.data ?? [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Mengambil satu pengumuman terbaru untuk ditampilkan di dashboard
  Future<Map<String, dynamic>> getLatestNotification(int userId) async {
    try {
      final response = await _dio.get(
        '$_userUrl/get-notification-latest',
        queryParameters: {"userId": userId},
      );
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return {
          "title": "No Announcements",
          "message": "Stay tuned for the latest information from us.",
          "createdAt": DateTime.now().toIso8601String(),
        };
      }
      throw _handleError(e);
    }
  }

  /// Mengambil seluruh daftar pengumuman
  Future<List<dynamic>> getAllNotifications(int userId) async {
    try {
      final response = await _dio.get(
        '$_userUrl/get-notifications-all',
        queryParameters: {"userId": userId},
      );
      return response.data ?? [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Mengirimkan data presensi (Masuk & Keluar) beserta lokasi GPS
  Future<Map<String, dynamic>> submitAttendance({
    required int userId,
    required double lat,
    required double lng,
    required bool isCheckIn,
  }) async {
    try {
      final String action = isCheckIn ? 'checkin' : 'checkout';
      final response = await _dio.post(
        '$_userUrl/$action',
        data: {
          "userId": userId,
          "userLatitude": lat,
          "userLongitude": lng,
          "notes":
              isCheckIn ? "In: Standard Working Hours" : "Out: Shift Completed",
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// koordinat lokasi kantor
  Future<List<dynamic>> getOfficeLocation() async {
    try {
      final response = await _dio.get('$_adminUrl/get-office-location');

      final data = response.data;

      if (data is List) {
        return data;
      } else if (data is Map) {
        return [data];
      }

      return [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // ADMIN
  // ---------------------------------------------------------------------------

  /// [Admin] Mengambil daftar seluruh karyawan/pengguna
  Future<List<dynamic>> getAllUsers() async {
    try {
      final response = await _dio.get('$_adminUrl/get-user-all');
      return response.data ?? [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// [Admin] Mengambil semua riwayat presensi seluruh karyawan hari ini
  Future<List<dynamic>> getAllAttendance() async {
    try {
      final response = await _dio.get('$_adminUrl/get-attendance');
      return response.data ?? [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// [Admin] Mendapatkan daftar seluruh notifikasi yang pernah dikirim
  Future<List<dynamic>> getAllNotificationsGeneral() async {
    try {
      final response = await _dio.get('$_adminUrl/get-notifications-all');
      return response.data ?? [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// [Admin] Membuat dan menyebarkan pengumuman baru (Broadcast)
  Future<void> addNotificationGeneral(String title, String message) async {
    try {
      await _dio.post(
        '$_adminUrl/add-notification',
        data: {"title": title, "message": message},
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// [Admin] Menghapus pengumuman berdasarkan ID tertentu
  Future<void> deleteNotification(int notificationId) async {
    try {
      await _dio.delete(
        '$_adminUrl/delete-notification',
        data: {"notificationId": notificationId},
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// [Admin] Mendaftarkan pengguna baru ke sistem
  Future<void> registerUser({
    required String name,
    required String email,
    required String password,
    required String role,
    required String nimNip,
  }) async {
    try {
      await _dio.post(
        '$_adminUrl/add-user',
        data: {
          "name": name,
          "usernameEmail": email,
          "password": password,
          "role": role.toLowerCase(),
          "nimNip": nimNip,
        },
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// [Admin] Mengubah data user yang sudah ada
  Future<void> updateUser({
    required int userId,
    required String name,
    required String email,
    required String role,
    required String nimNip,
    String? password,
  }) async {
    try {
      await _dio.put(
        '$_adminUrl/edit-user',
        data: {
          "userId": userId,
          "name": name,
          "usernameEmail": email,
          "role": role,
          "nimNip": nimNip,
          if (password != null && password.isNotEmpty) "password": password,
        },
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// [Admin] Menghapus pengguna berdasarkan ID
  Future<void> deleteUser(int userId) async {
    try {
      await _dio.delete('$_adminUrl/delete-user', data: {"userId": userId});
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// [Admin] Update lokasi kantor
  Future<void> addOfficeLocation({
    required String name,
    required double lat,
    required double lng,
    required int radius,
  }) async {
    try {
      await _dio.post(
        '$_adminUrl/set-office-location',
        data: {
          "locationName": name,
          "latitude": lat,
          "longitude": lng,
          "radius": radius,
        },
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // ERROR HANDLING
  // ---------------------------------------------------------------------------

  /// Mengonversi error Dio menjadi pesan yang dapat dimengerti oleh pengguna
  Exception _handleError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout) {
      return Exception(
        "Connection timed out. Please check your internet connection.",
      );
    }
    if (e.type == DioExceptionType.connectionError) {
      return Exception(
        "Server is unreachable. Please make sure the server is running.",
      );
    }
    // Mengambil pesan error dari field 'error' yang dikirim oleh backend
    final message = e.response?.data['error'] ?? "A system error occurred.";
    return Exception(message);
  }
}
