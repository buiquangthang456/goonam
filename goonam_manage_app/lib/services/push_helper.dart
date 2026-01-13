// import 'dart:io';
// import 'package:dio/dio.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'auth_service.dart';
//
// class PushHelper {
//   static Future<void> registerDeviceToken(String sanctumToken) async {
//     try {
//       // 🔹 Nếu là Windows → bỏ qua Firebase
//       if (Platform.isWindows) {
//         print("💡 Skipped FirebaseMessaging on Windows — using mock token");
//         final dio = Dio(BaseOptions(
//           baseUrl: AuthService.getBaseUrl(),
//           headers: {"Authorization": "Bearer $sanctumToken"},
//         ));
//
//         // Gửi mock token để test backend (nếu cần)
//         await dio.post('/device-tokens', data: {
//           "token": "mock_windows_token",
//           "device_type": "windows",
//         });
//
//         print("🪟 Mock device token sent successfully");
//         return;
//       }
//
//       // ✅ Đảm bảo Firebase đã init (cho Android / iOS / macOS)
//       if (Firebase.apps.isEmpty) {
//         await Firebase.initializeApp();
//         print("🔥 Firebase initialized in PushHelper");
//       }
//
//       // ✅ Lấy token FCM thật
//       final fcmToken = await FirebaseMessaging.instance.getToken();
//       print("📱 FCM token: $fcmToken");
//
//       if (fcmToken != null) {
//         final dio = Dio(BaseOptions(
//           baseUrl: AuthService.getBaseUrl(),
//           headers: {"Authorization": "Bearer $sanctumToken"},
//         ));
//
//         await dio.post('/device-tokens', data: {
//           "token": fcmToken,
//           "device_type": Platform.operatingSystem, // vd: android, ios, macos
//         });
//
//         print("✅ Device token registered successfully");
//       }
//     } catch (e) {
//       print("⚠️ PushHelper.registerDeviceToken failed: $e");
//     }
//   }
// }
