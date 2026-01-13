// import 'dart:async';
// import 'package:goonam_manage_app/services/auth_service.dart';
// import 'package:goonam_manage_app/services/notification_helper.dart';
// import 'package:goonam_manage_app/services/windows_badge_helper.dart';
// import 'package:goonam_manage_app/services/comment_service.dart';
// import 'dart:io';
//
// import 'desktop_notification_service.dart';
//
// /// 🔁 Dịch vụ tự động kiểm tra comment mới cho app Windows
// class CommentPollingService {
//   static Timer? _timer;
//   static bool _isRunning = false;
//   static int _lastSeenCommentId = 0; // ✅ ID comment mới nhất đã thông báo
//   static final Set<int> _notifiedComments = {}; // tránh lặp nếu trùng API
//
//   static void start() {
//     if (_isRunning) return;
//     _isRunning = true;
//     print("🚀 CommentPollingService started");
//
//     _timer = Timer.periodic(const Duration(seconds: 30), (_) async {
//       try {
//         final token = await AuthService.getToken();
//         if (token == null) return;
//
//         final res = await CommentService.getUnreadComments(sinceId: _lastSeenCommentId);
//         final orders = List<Map<String, dynamic>>.from(res['orders'] ?? []);
//         final latestId = res['latest_id'] ?? _lastSeenCommentId;
//
//         if (orders.isEmpty) return;
//
//         for (final c in orders) {
//           final cid = c['comment_id'];
//           if (!_notifiedComments.contains(cid)) {
//             _notifiedComments.add(cid);
//             await NotificationHelper.show(
//               "💬 Đơn #${c['order_no']}",
//               c['body'],
//               orderId: c['order_id'],
//             );
//             print("🔔 Notify comment_id=$cid");
//           }
//         }
//
//         if (latestId > _lastSeenCommentId) {
//           _lastSeenCommentId = latestId;
//         }
//
//         // Cập nhật badge tổng
//         // Cập nhật badge tổng (UI + icon app)
//         final unreadCount = res['unread_total'] ?? 0;
//         GlobalBadge.unreadComments.value = unreadCount;
//         await NotificationHelper.updateBadge(unreadCount);
//         print("📊 Cập nhật badge: $unreadCount");
//       } catch (e, st) {
//         print("❌ [Polling] error: $e\n$st");
//       }
//     });
//   }
//
//   static void stop() {
//     _timer?.cancel();
//     _isRunning = false;
//     print("🧹 CommentPollingService stopped");
//   }
// }
