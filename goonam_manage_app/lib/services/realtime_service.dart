import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

import 'auth_service.dart';
import 'notification_helper.dart';
import 'windows_badge_helper.dart';

class RealtimeService {
  static final PusherChannelsFlutter _pusher =
  PusherChannelsFlutter.getInstance();

  static bool _connected = false;
  static int? _userId;
  // 🟢 Stream phát ra khi có comment mới
  static final StreamController<Map<String, dynamic>> _commentStreamController =
  StreamController.broadcast();

  static Stream<Map<String, dynamic>> get commentStream =>
      _commentStreamController.stream;
  /// Gọi sau khi đăng nhập: RealtimeService.init(user.id)
  static Future<void> init(int userId) async {
    if (Platform.isWindows) {
      print("💡 Windows không hỗ trợ Pusher — bỏ qua realtime.");
      return;
    }
    if (_connected && _userId == userId) return;
    _userId = userId;

    final token = await AuthService.getToken();
    if (token == null) {
      print("⚠️ Chưa có token -> bỏ qua realtime");
      return;
    }

    try {
      await _pusher.init(
        apiKey: 'c32d2fcf23a1acd996f7',         // 🔑 key của bạn
        cluster: 'ap1',                          // 🌏 cluster của bạn
        authEndpoint: 'https://api.goonamvina.com/broadcasting/auth',

        /// KÝ yêu cầu auth cho private channel bằng Bearer token (Sanctum)
        onAuthorizer: (String channelName, String socketId, dynamic _options) async {
          final res = await http.post(
            Uri.parse('https://api.goonamvina.com/broadcasting/auth'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/x-www-form-urlencoded',
              'Accept': 'application/json',
            },
            body: {
              'channel_name': channelName,
              'socket_id': socketId,
            },
          );
          return jsonDecode(res.body);
        },

        onConnectionStateChange: (String current, String previous) {
          print("🔌 Pusher: $previous → $current");
        },
        onError: (String message, int? code, dynamic e) {
          print("❌ Pusher error: $message (code=$code) ex=$e");
        },
      );

      await _pusher.connect();

      // ====== KÊNH USER (private-user.{id}) ======
      await _pusher.subscribe(
        channelName: 'private-user.$userId',
        onSubscriptionSucceeded: (String channelName, dynamic data) {
          print('✅ Subscribed $channelName');
        },
        onEvent: (PusherEvent event) async {
          print('📡 ${event.channelName} -> ${event.eventName}: ${event.data}');

          try {
            final Map<String, dynamic> payload =
            (event.data != null && event.data!.isNotEmpty)
                ? jsonDecode(event.data!)
                : <String, dynamic>{};

            switch (event.eventName) {
              case 'unread.updated':
                final int unread = (payload['unreadCount'] ??
                    payload['unread_count'] ??
                    0) as int;
                GlobalBadge.unreadComments.value = unread;
                await NotificationHelper.updateBadge(unread);
                // 🪟 Cập nhật badge trên icon app (Windows)
                // if (Platform.isWindows) {
                //   WindowsBadgeHelper.updateBadge(unread);
                // }
                break;

              case 'comment.added':
                final int orderId = (payload['order_id'] ?? 0) as int;
                final String body =
                (payload['body'] ?? '(Không có nội dung)').toString();
                final commentJson = payload['comment']; // ⚠️ backend phải gửi full comment JSON

                // 🟢 Đưa event vào stream để UI nhận
                if (commentJson != null) {
                  _commentStreamController.add({
                    'order_id': orderId,
                    'comment': commentJson,
                  });
                }

                await NotificationHelper.show('💬 Đơn #$orderId', body, orderId: orderId);
                break;
            }
          } catch (e) {
            print('⚠️ Parse event error: $e');
          }
        },
      );

      _connected = true;
      print("✅ Realtime đã kết nối cho user.$userId");
    } catch (e, st) {
      print("⚠️ RealtimeService.init error: $e\n$st");
    }
  }

  /// Gọi khi logout
  static Future<void> disconnect() async {
    try {
      if (_connected) {
        if (_userId != null) {
          await _pusher.unsubscribe(channelName: 'private-user.$_userId');
        }
        await _pusher.disconnect();
      }
      // 🧹 Xóa badge khi ngắt kết nối
      // if (Platform.isWindows) {
      //   WindowsBadgeHelper.updateBadge(0);
      //   WindowsBadgeHelper.dispose();
      // }
    } catch (_) {}
    _connected = false;
    _userId = null;
    print("🔌 Pusher disconnected");
  }
}
