import 'dart:convert';
import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../firebase_options.dart';
import '../main.dart';

class AuthService {
  static String getBaseUrl() {
    const bool isProduction = bool.fromEnvironment('dart.vm.product');

    if (isProduction) {
      return 'https://api.goonamvina.com/api';
    }

    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000/api';
    } else if (Platform.isIOS || Platform.isMacOS) {
      return 'http://127.0.0.1:8000/api';
    } else if (Platform.isWindows) {
      return 'http://localhost:8000/api';
    } else {
      return 'http://localhost:8000/api';
    }
  }

  static final Dio _dio = Dio(BaseOptions(
    baseUrl: getBaseUrl(),
    connectTimeout: const Duration(seconds: 60),
    receiveTimeout: const Duration(seconds: 120),
  ))
    ..interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401) {
          debugPrint("⚠️ Token expired or invalid, redirecting to login...");
          await handle401();
          return;
        }
        return handler.next(e);
      },
    ));

  static Dio get dio => _dio;
  static const _storage = FlutterSecureStorage();

  // ✅ HÀM PHỤ: Parse int an toàn
  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  // ✅ HÀM PHỤ: Chuẩn hóa user data
  static Map<String, dynamic> _normalizeUser(Map<String, dynamic> user) {
    return {
      'id': _parseInt(user['id']), // ✅ CHUẨN HÓA id VỀ int
      'name': user['name']?.toString() ?? '',
      'email': user['email']?.toString() ?? '',
      'role': user['role']?.toString() ?? '',
    };
  }

  static Future<void> login(String name, String password) async {
    try {
      print("🌍 Base URL: ${_dio.options.baseUrl}");
      print("➡️ Login request: /auth/login");

      final res = await _dio.post('/auth/login', data: {
        'name': name,
        'password': password,
      });

      print("✅ Login response = ${res.data}");

      final token = res.data['token'];
      final rawUser = res.data['user'] as Map<String, dynamic>;

      // ✅ CHUẨN HÓA user data
      final user = _normalizeUser(rawUser);

      print("📦 Normalized user: $user");

      await _storage.write(key: 'token', value: token);
      await _storage.write(
        key: 'user',
        value: jsonEncode({
          'data': user,
          'lastFetchedAt': DateTime.now().toIso8601String(),
        }),
      );

      await _registerDeviceToken(token);
    } on DioException catch (e) {
      print("❌ Login failed: ${e.message}");
      if (e.response != null) {
        print("❌ Response: ${e.response?.data}");
      }
      rethrow;
    }
  }

  static Future<void> _registerDeviceToken(String sanctumToken) async {
    try {
      String? fcmToken;

      if (Platform.isWindows) {
        print("💡 Skipped FirebaseMessaging on Windows (no FCM)");
        return;
      }

      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
        print("🔥 Firebase initialized for device token");
      }

      fcmToken = await FirebaseMessaging.instance.getToken();
      print("📱 FCM token: $fcmToken");

      if (fcmToken == null) {
        print("⚠️ No device token available, skipping registration");
        return;
      }

      await _dio.post(
        '/device-tokens',
        data: {
          "token": fcmToken,
          "device_type": Platform.operatingSystem,
        },
        options: Options(headers: {"Authorization": "Bearer $sanctumToken"}),
      );

      print("✅ Device token registered successfully");

    } catch (e, st) {
      print("⚠️ Error registering device token: $e\n$st");
    }
  }

  static Future<void> logout() async {
    final token = await getToken();
    if (token != null) {
      try {
        await _dio.post(
          '/auth/logout',
          options: Options(headers: {"Authorization": "Bearer $token"}),
        );
      } catch (_) {}
    }
    await clearUserCache();
  }

  static Future<void> clearUserCache() async {
    await _storage.delete(key: 'token');
    await _storage.delete(key: 'user');
  }

  static Future<String?> getToken() => _storage.read(key: 'token');

  static Future<Map<String, dynamic>?> getStoredUser() async {
    final raw = await _storage.read(key: 'user');
    print("DEBUG getStoredUser raw = $raw");
    if (raw == null) return null;

    try {
      final parsed = jsonDecode(raw);
      final rawUser = parsed['data'] as Map<String, dynamic>;

      // ✅ CHUẨN HÓA user data khi đọc từ cache
      final user = _normalizeUser(rawUser);

      final lastFetchedAt =
          DateTime.tryParse(parsed['lastFetchedAt'] ?? '') ?? DateTime(2000);

      if (DateTime.now().difference(lastFetchedAt).inDays >= 7) {
        try {
          return await refreshUser();
        } catch (e) {
          print("⚠️ refreshUser failed: $e");
        }
      }

      return user;
    } catch (e) {
      print("❌ Error parsing stored user: $e");
      await clearUserCache(); // Xóa cache lỗi
      return null;
    }
  }

  static Future<Map<String, dynamic>?> me() async {
    final token = await getToken();
    if (token == null) return null;

    try {
      final res = await _dio.get(
        '/me',
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      final rawUser = res.data as Map<String, dynamic>;

      // ✅ CHUẨN HÓA user data
      return _normalizeUser(rawUser);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await clearUserCache();
        throw Exception('Token expired, please login again');
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> refreshUser() async {
    final token = await getToken();
    if (token == null) return null;

    try {
      final res = await _dio.get(
        '/me',
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      final rawUser = res.data as Map<String, dynamic>;

      // ✅ CHUẨN HÓA user data
      final user = _normalizeUser(rawUser);

      await _storage.write(
        key: 'user',
        value: jsonEncode({
          'data': user,
          'lastFetchedAt': DateTime.now().toIso8601String(),
        }),
      );

      return user;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await clearUserCache();
        throw Exception('Token expired, please login again');
      }
      rethrow;
    }
  }

  static Future<void> handle401() async {
    await clearUserCache();

    messengerKey.currentState?.showSnackBar(
      const SnackBar(
        content: Text("Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại."),
        duration: Duration(seconds: 3),
      ),
    );

    navigatorKey.currentState
        ?.pushNamedAndRemoveUntil('/login', (route) => false);
  }
  static Future<String?> getRole() async {
    // ✅ 1. Thử lấy từ cache trước (nhanh)
    final cachedUser = await getStoredUser();

    if (cachedUser != null) {
      final lastFetched = await _storage.read(key: 'user');
      if (lastFetched != null) {
        final parsed = jsonDecode(lastFetched);
        final lastFetchedAt = DateTime.tryParse(parsed['lastFetchedAt'] ?? '') ?? DateTime(2000);

        // ✅ Nếu cache < 1 giờ → dùng cache
        if (DateTime.now().difference(lastFetchedAt).inHours < 1) {
          final role = cachedUser['role'] as String?;
          return role;
        }
      }
    }

    // ✅ 2. Cache hết hạn hoặc không có → lấy từ API
    try {
      final user = await me(); // Cập nhật cache luôn
      final role = user?['role'] as String?;
      return role;
    } catch (e) {
      // ✅ 3. API lỗi → dùng cache cũ (nếu có)
      return cachedUser?['role'] as String?;
    }
  }
}