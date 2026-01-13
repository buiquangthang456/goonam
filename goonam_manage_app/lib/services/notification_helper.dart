import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:flutter/foundation.dart';
import 'package:goonam_manage_app/main.dart';


extension NotificationIconExt on NotificationHelper {
  static Future<String> ensureIconCopied() async {
    try {
      final bytes = await rootBundle.load('assets/logo_icon.ico');
      final dir = Directory.systemTemp;
      final file = File('${dir.path}\\goonam_icon.ico');
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      return file.path;
    } catch (e) {
      print("⚠️ Không thể copy icon: $e");
      return '';
    }
  }
}
class NotificationHelper {
  static final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    final androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    final initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          final orderId = int.tryParse(payload);
          if (orderId != null) {
            print("📦 Người dùng click vào thông báo đơn #$orderId");
            navigatorKey.currentState?.pushNamed(
              '/orders',
              arguments: {'orderId': orderId},
            );
          }
        }
      },
    );

  }

  /// 🔧 Copy icon vào thư mục tạm để WinToast luôn load được (dù máy nào cũng có)
  static Future<String> _copyIconToTemp() async {
    try {
      final bytes = await rootBundle.load('assets/logo_icon.ico');
      final dir = Directory.systemTemp;
      final file = File('${dir.path}\\goonam_icon.ico');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      return file.path;
    } catch (e) {
      print("⚠️ Không tìm thấy logo_icon.ico, dùng mặc định");
      return '';
    }
  }
  /// ✅ Đảm bảo icon được copy sang thư mục tạm của Windows
  static Future<String> ensureIconCopied() async {
    final dir = await getTemporaryDirectory();
    final iconPath = '${dir.path}/logo_icon.ico';
    final file = File(iconPath);

    if (!await file.exists()) {
      final data = await rootBundle.load('assets/logo_icon.ico');
      await file.writeAsBytes(data.buffer.asUint8List());
    }

    return iconPath;
  }
  static Future<void> show(String? title, String? body, {int? orderId}) async {
    try {

      // 🤖 Android notification
      const androidDetails = AndroidNotificationDetails(
        'desktop_channel',
        'Desktop Notifications',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );
      final platformDetails = NotificationDetails(android: androidDetails);

      await _plugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title ?? 'Thông báo mới',
        body ?? '',
        platformDetails,
        payload: orderId?.toString(),
      );

      print("🔔 Hiện thông báo (Android/iOS): ${title ?? ''}");
    } catch (e, st) {
      print("⚠️ NotificationHelper.show() error: $e\n$st");
    }
  }

  static Future<void> updateBadge(int count) async {
    // ❗ Không hỗ trợ Windows → return luôn để tránh crash
    if (Platform.isWindows) {
      print("💡 Badge not supported on Windows — skip updateBadge()");
      return;
    }

    try {
      final supported = await FlutterAppBadger.isAppBadgeSupported();
      if (!supported) {
        print('⚠️ Badge not supported on this platform');
        return;
      }

      if (count > 0) {
        await FlutterAppBadger.updateBadgeCount(count);
      } else {
        await FlutterAppBadger.removeBadge();
      }
    } catch (e, st) {
      print("⚠️ updateBadge() error: $e\n$st");
    }
  }

}
class GlobalBadge {
  static final unreadComments = ValueNotifier<int>(0);
}