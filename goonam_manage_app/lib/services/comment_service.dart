import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';

import 'notification_helper.dart';

final String apiUrl = AuthService.getBaseUrl();
class CommentService {
  static final Dio _dio = AuthService.dio;

  static Future<Map<String, dynamic>> getUnreadComments({int sinceId = 0}) async {
    final token = await AuthService.getToken();
    final url = '$apiUrl/comments/unread-count?since_id=$sinceId';

    final res = await _dio.get(
      "/comments/unread-count",
      queryParameters: {"since_id": sinceId},
    );
    return res.data;

    // if (res.statusCode == 200) {
    //   return jsonDecode(res.body);
    // } else {
    //   throw Exception("Lỗi tải comment chưa đọc");
    // }
  }

  static Future<void> markAllAsRead() async {
    final token = await AuthService.getToken();
    if (token == null) return;
    try {
      await _dio.post(
        '/comments/mark-all-as-read',
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );
    } catch (e) {
      print("⚠️ markAllAsRead error: $e");
    }
    GlobalBadge.unreadComments.value = 0;
    await NotificationHelper.updateBadge(0);
  }
  static Future<void> markOrderCommentsAsRead(int orderId) async {
    final token = await AuthService.getToken();
    if (token == null) return;
    try {
      await _dio.post(
        '/comments/mark-all-as-read',
        data: {'order_id': orderId},
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      // ✅ Xóa badge sau khi đọc
      await NotificationHelper.updateBadge(0);

    } catch (e) {
      print("⚠️ markOrderCommentsAsRead error: $e");
    }
    GlobalBadge.unreadComments.value = 0;
    await NotificationHelper.updateBadge(0);
  }
}
