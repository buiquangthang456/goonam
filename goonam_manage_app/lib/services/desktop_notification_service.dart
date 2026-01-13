// import 'dart:async';
// import 'package:flutter/foundation.dart';
//
// import 'notification_helper.dart';
// import 'auth_service.dart';
// import 'dart:io';
// import 'package:path_provider/path_provider.dart';
//
// class Logger {
//   static Future<void> log(String text) async {
//     print(text);
//     if (!kDebugMode) return; // 🚫 Không ghi file trong bản release
//
//     try {
//       final dir = Directory.systemTemp;
//       final file = File('${dir.path}\\goonam_debug_log.txt');
//       await file.writeAsString(
//         '${DateTime.now()}: $text\n',
//         mode: FileMode.append,
//       );
//     } catch (e) {
//       print('⚠️ Logger error: $e');
//     }
//   }
// }
// class DesktopNotificationService {
//   static Timer? _timer;
//   static final Map<int, String> _lastNotifiedTime = {};
//   static void start() {
//     _timer?.cancel();
//     Logger.log("🚀 DesktopNotificationService started");
//
//     _timer = Timer.periodic(const Duration(seconds: 10), (timer) async {
//       try {
//         Logger.log("🔍 Polling started...");
//
//         final token = await AuthService.getToken();
//         if (token == null) {
//           Logger.log("⚠️ No token, skip polling");
//           return;
//         }
//
//         final dio = AuthService.dio;
//         final res = await dio.get('/comments/unread-count');
//
//         final unreadTotal = res.data['unread_total'] ?? 0;
//         final orders = res.data['orders'] ?? [];
//
//         Logger.log("📊 unread_total = $unreadTotal, orders_count = ${orders.length}");
//
//         await NotificationHelper.updateBadge(unreadTotal);
//
//         if (unreadTotal > 0 && orders.isNotEmpty) {
//           final latest = orders.first;
//           final orderId = latest['order_id'];
//
//           // ⚙️ Chỉ hiện khi có comment mới so với lần trước
//           if (latest['created_at'] != _lastNotifiedTime[orderId]) {
//             _lastNotifiedTime[orderId] = latest['created_at'];
//
//             await NotificationHelper.show(
//               "💬 Bình luận mới trong đơn #${latest['order_no']}",
//               latest['latest_comment'] ?? '',
//
//             );
//             Logger.log("🔔 Notification shown for order #${latest['order_no']}");
//           }
//         }
//       } catch (e, st) {
//         Logger.log("❌ Polling error: $e\n$st");
//       }
//     });
//   }
//
//   static void stop() {
//     _timer?.cancel();
//   }
// }
