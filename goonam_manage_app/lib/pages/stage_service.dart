import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/stage.dart';
import '../services/auth_service.dart';

class StageService {
  static final Dio _dio = AuthService.dio;
  static final _storage = const FlutterSecureStorage();

  /// 🔹 Hàm chung hiển thị thông báo lỗi thân thiện
  static void _handleError(BuildContext context, DioException e) {
    String msg;
    final status = e.response?.statusCode;

    if (status == 403) {
      msg = "❌ Bạn không có quyền thực hiện hành động này.";
    } else if (status == 401) {
      msg = "⚠️ Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại.";
    } else if (status == 404) {
      msg = "Không tìm thấy dữ liệu.";
    } else if (status == 500) {
      msg = "Lỗi hệ thống, vui lòng thử lại sau.";
    } else {
      msg = "Đã xảy ra lỗi: ${e.message}";
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// ✅ Đánh dấu hoàn thành giai đoạn
  static Future<Stage?> markDone(BuildContext context, int orderId, int stageId) async {
    try {
      final token = await _storage.read(key: 'token');
      final res = await _dio.put(
        "/orders/$orderId/stages/$stageId/done",
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );
      return Stage.fromJson(res.data);
    } on DioException catch (e) {
      _handleError(context, e);
      return null;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi không xác định: $e")),
      );
      return null;
    }
  }

  /// ✅ Bắt đầu giai đoạn
  static Future<Stage?> start(BuildContext context, int orderId, int stageId) async {
    try {
      final token = await _storage.read(key: 'token');
      final res = await _dio.put(
        "/orders/$orderId/stages/$stageId/start",
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );
      return Stage.fromJson(res.data);
    } on DioException catch (e) {
      _handleError(context, e);
      return null;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi không xác định: $e")),
      );
      return null;
    }
  }
  /// ✅ Cập nhật thời gian công đoạn (có thể kèm lý do gia hạn)
  static Future<Stage?> updateStageTime(
      BuildContext context,
      int orderId,
      int stageId,
      DateTime? newStart,
      DateTime? newEnd, {
        String? delayReason,
      }) async {
    final token = await _storage.read(key: 'token');

    try {
      final Map<String, dynamic> payload = {};

      if (newStart != null) {
        payload["planned_start"] = newStart.toIso8601String();
      }
      if (newEnd != null) {
        payload["planned_end"] = newEnd.toIso8601String();
      }
      if (delayReason != null && delayReason.isNotEmpty) {
        payload["delay_reason"] = delayReason;
      }

      final res = await _dio.put(
        "/orders/$orderId/stages/$stageId/time",
        data: payload,
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Cập nhật thời gian công đoạn thành công")),
      );

      return Stage.fromJson(res.data['stage'] ?? res.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 422) {
        final msg = e.response?.data['message'] ?? "Vui lòng nhập lý do gia hạn!";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("⚠️ $msg")),
        );
      } else {
        _handleError(context, e);
      }
      return null;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi không xác định: $e")),
      );
      return null;
    }
  }

  /// ✅ Cập nhật lý do trễ công đoạn
  static Future<Stage?> updateDelayReason(
      BuildContext context, int orderId, int stageId, String reason) async {
    final token = await _storage.read(key: 'token');
    try {
      final res = await _dio.put(
        "/orders/$orderId/stages/$stageId/delay-reason",
        data: {"delay_reason": reason},
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Đã lưu lý do trễ")),
      );

      return Stage.fromJson(res.data);
    } on DioException catch (e) {
      _handleError(context, e);
      return null;
    }
  }
  /// 📊 Xuất kế hoạch ngày (Excel)
  static Future<void> exportDailyPlan(BuildContext context, DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final token = await AuthService.getToken();

    final dio = Dio(BaseOptions(
      baseUrl: AuthService.getBaseUrl(),
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));

    try {
      // 🟩 Xin quyền ghi file (Android)
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("❌ Không có quyền ghi file")),
          );
          return;
        }
      }

      // 🟩 Lấy thư mục download
      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory("/storage/emulated/0/Download");
      } else if (Platform.isWindows || Platform.isMacOS) {
        dir = await getDownloadsDirectory();
      } else if (Platform.isIOS) {
        dir = await getApplicationDocumentsDirectory();
      }

      if (dir == null) throw Exception("Không tìm thấy thư mục lưu file");

      // ✅ Tên file có timestamp để tránh trùng
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = "KeHoachNgay_${DateFormat('yyyyMMdd').format(date)}_$timestamp.xlsx";
      final filePath = "${dir.path}/$fileName";

      debugPrint("📡 Gọi API: /stages/daily-plan/$dateStr");
      debugPrint("💾 File sẽ lưu tại: $filePath");

      // 🟩 Tải file Excel
      await dio.download(
        "/stages/daily-plan/$dateStr",
        filePath,
        options: Options(
          headers: {
            "Authorization": "Bearer $token",
            "Accept": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
          },
          responseType: ResponseType.bytes,
        ),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            debugPrint("📦 Download: ${(received / total * 100).toStringAsFixed(0)}%");
          }
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ Đã tải về: $fileName")),
      );

      await OpenFilex.open(filePath);

    } on DioException catch (e) {
      final msg = e.response?.data['message'] ?? e.message ?? "Lỗi không xác định";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Lỗi xuất kế hoạch: $msg")),
      );
      debugPrint("❌ Lỗi Dio: ${e.response?.data}");
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Lỗi: $e")),
      );
    }
  }
  static Future<Stage?> updateMaterialRequestDate(
      BuildContext context, int orderId, int stageId, DateTime date) async {
    final token = await _storage.read(key: 'token');
    try {
      final res = await _dio.put(
        "/orders/$orderId/stages/$stageId/material-request",
        data: {"material_request_date": date.toIso8601String()},
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Đã cập nhật ngày yêu cầu vật tư")),
      );

      return Stage.fromJson(res.data['stage'] ?? res.data);
    } on DioException catch (e) {
      _handleError(context, e);
      return null;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi không xác định: $e")),
      );
      return null;
    }
  }
}
