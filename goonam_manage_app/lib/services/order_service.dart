import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/order.dart';
import 'auth_service.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:month_year_picker/month_year_picker.dart';

class OrderService {
  static final Dio _dio = AuthService.dio;
  static final _storage = const FlutterSecureStorage();

  // 🔹 Hàm xử lý lỗi tập trung (hiển thị SnackBar thông báo thân thiện)
  static void handleError(BuildContext context, DioException e) {
    final status = e.response?.statusCode;
    String msg;

    if (status == 403) {
      msg = "❌ Bạn không có quyền thực hiện hành động này.";
    } else if (status == 401) {
      msg = "⚠️ Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại.";
    } else if (status == 404) {
      msg = "Không tìm thấy dữ liệu yêu cầu.";
    } else if (status == 422) {
      msg = "Dữ liệu không hợp lệ, vui lòng kiểm tra lại.";
    } else if (status == 500) {
      msg = "⚙️ Lỗi hệ thống, vui lòng thử lại sau.";
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      msg = "⏳ Mất kết nối hoặc phản hồi quá lâu. Hãy thử lại.";
    } else {
      msg = "Đã xảy ra lỗi: ${e.message}";
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ✅ MỚI: Lấy danh sách đơn hàng kèm metadata (pagination)
  static Future<Map<String, dynamic>> getOrdersWithMeta({String? search, int page = 1}) async {
    final token = await AuthService.getToken();

    final queryParams = <String, dynamic>{};
    if (search != null) queryParams['search'] = search;
    if (page > 1) queryParams['page'] = page;

    final res = await _dio.get(
      "/orders",
      queryParameters: queryParams,
      options: Options(headers: {"Authorization": "Bearer $token"}),
    );

    // ✅ Kiểm tra định dạng response
    if (res.data is Map && res.data['type'] == 'all') {
      // < 50 đơn → lấy tất cả
      final list = res.data['data'] as List;
      return {
        'data': list.map((e) => Order.fromJson(e)).toList(),
        'meta': null, // Không có pagination
      };
    } else if (res.data is Map && res.data['data'] != null) {
      // >= 50 đơn → pagination
      final list = res.data['data'] as List;
      return {
        'data': list.map((e) => Order.fromJson(e)).toList(),
        'meta': {
          'current_page': res.data['current_page'],
          'last_page': res.data['last_page'],
          'total': res.data['total'],
          'per_page': res.data['per_page'],
        },
      };
    } else {
      // Format cũ (fallback)
      final list = res.data as List;
      return {
        'data': list.map((e) => Order.fromJson(e)).toList(),
        'meta': null,
      };
    }
  }

  // ✅ GIỮ NGUYÊN: Hàm cũ để backward compatible
  // 🔸 Lấy danh sách đơn hàng
  static Future<List<Order>> getOrders({String? search, int page = 1}) async {
    final response = await getOrdersWithMeta(search: search, page: page);
    return response['data'] as List<Order>;
  }

  // 🔸 Lấy chi tiết đơn hàng
  static Future<Order> getOrderDetail(int id) async {
    final token = await _storage.read(key: 'token');
    try {
      final res = await _dio.get(
        "/orders/$id",
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );
      return Order.fromJson(res.data);
    } on DioException catch (e) {
      throw Exception("Lỗi gọi API /orders/$id: ${e.message}");
    }
  }

  /// Tạo đơn hàng mới
  static Future<Order?> createOrder(BuildContext context, Map<String, dynamic> data) async {
    final token = await AuthService.getToken();

    try {
      final res = await _dio.post(
        "/orders",
        data: data,
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Đã tạo đơn hàng mới")),
      );

      return Order.fromJson(res.data);
    } on DioException catch (e) {
      // ✅ Xử lý lỗi 422 - Validation Error
      if (e.response?.statusCode == 422) {
        final message = e.response?.data['message'] ?? 'Dữ liệu không hợp lệ';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
      } else if (e.response?.statusCode == 403) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("❌ Bạn không có quyền thực hiện hành động này"),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Lỗi: ${e.message}"),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  /// Cập nhật đơn hàng
  static Future<Order?> updateOrder(
      BuildContext context,
      int orderId,
      Map<String, dynamic> data,
      ) async {
    final token = await AuthService.getToken();

    try {
      final res = await _dio.put(
        "/orders/$orderId",
        data: data,
        options: Options(
            headers: {
              "Authorization": "Bearer $token",
              "Accept": "application/json", // ✅ THÊM DÒNG NÀY NẾU CHƯA CÓ
              "Content-Type": "application/json", // ✅ THÊM DÒNG NÀY NẾU CHƯA CÓ
            }
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Đã cập nhật đơn hàng")),
      );

      return Order.fromJson(res.data);
    } on DioException catch (e) {
      // ✅ Xử lý lỗi 422 - Validation Error
      if (e.response?.statusCode == 422) {
        final message = e.response?.data['message'] ?? 'Dữ liệu không hợp lệ';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
      } else if (e.response?.statusCode == 403) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("❌ Bạn không có quyền thực hiện hành động này"),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Lỗi: ${e.message}"),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  // 🔸 Xóa đơn hàng
  static Future<void> deleteOrder(BuildContext context, int id) async {
    final token = await _storage.read(key: 'token');
    try {
      await _dio.delete(
        "/orders/$id",
        options: Options(
          headers: {
            "Authorization": "Bearer $token",
            "Accept": "application/json",
          },
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🗑️ Đơn hàng đã được chuyển vào thùng rác.")),
      );
    } on DioException catch (e) {
      handleError(context, e);
    }
  }

  // 🔸 Lấy danh sách comment
  static Future<List<Map<String, dynamic>>> getComments(int orderId) async {
    final token = await _storage.read(key: 'token');
    final res = await _dio.get(
      "/orders/$orderId/comments",
      options: Options(headers: {"Authorization": "Bearer $token"}),
    );
    return List<Map<String, dynamic>>.from(res.data);
  }

  // 🔸 Gửi comment mới
  static Future<Map<String, dynamic>?> addComment(
      BuildContext context, int orderId, String body) async {
    final token = await _storage.read(key: 'token');
    try {
      final res = await _dio.post(
        "/orders/$orderId/comments",
        data: {"body": body},
        options: Options(
          headers: {
            "Authorization": "Bearer $token",
            "Accept": "application/json",
            "Content-Type": "application/json",
          },
        ),
      );
      return res.data;
    } on DioException catch (e) {
      handleError(context, e);
      return null;
    }
  }

  // 🔸 Cập nhật comment
  static Future<Map<String, dynamic>?> updateComment(
      BuildContext context, int orderId, int commentId, String body) async {
    final token = await _storage.read(key: 'token');
    try {
      final res = await _dio.put(
        "/orders/$orderId/comments/$commentId",
        data: {"body": body},
        options: Options(
          headers: {"Authorization": "Bearer $token", "Accept": "application/json"},
        ),
      );
      return res.data;
    } on DioException catch (e) {
      handleError(context, e);
      return null;
    }
  }

  // 🔸 Xóa comment
  static Future<void> deleteComment(
      BuildContext context, int orderId, int commentId) async {
    final token = await _storage.read(key: 'token');
    try {
      await _dio.delete(
        "/orders/$orderId/comments/$commentId",
        options: Options(
          headers: {"Authorization": "Bearer $token", "Accept": "application/json"},
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🗑️ Bình luận đã được xóa.")),
      );
    } on DioException catch (e) {
      handleError(context, e);
    }
  }

  // 🔸 Xuất Excel đơn hàng (hỗ trợ Windows, Android, iOS, macOS)
  static Future<void> exportOrderExcel(
      BuildContext context, int orderId, String fileName) async {
    final token = await AuthService.getToken();
    final dio = Dio(BaseOptions(
      baseUrl: AuthService.getBaseUrl(),
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));

    try {
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("❌ Không có quyền ghi file")),
          );
          return;
        }
      }

      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory("/storage/emulated/0/Download");
      } else if (Platform.isWindows || Platform.isMacOS) {
        dir = await getDownloadsDirectory();
      } else if (Platform.isIOS) {
        dir = await getApplicationDocumentsDirectory();
      }

      if (dir == null) throw Exception("Không tìm thấy thư mục lưu file");

      final filePath = "${dir.path}/$fileName.xlsx";

      final response = await dio.download(
        "/orders/$orderId/export",
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
            debugPrint("📦 Download progress: ${(received / total * 100).toStringAsFixed(0)}%");
          }
        },
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ Đã tải về: $filePath")),
        );
        await OpenFilex.open(filePath);
      } else {
        throw Exception("Lỗi tải file: ${response.statusCode}");
      }
    } on DioException catch (e) {
      final msg = e.message ?? "Lỗi không xác định";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Lỗi xuất Excel: $msg")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Lỗi xuất Excel: $e")),
      );
    }
  }

  // 🔸 Lấy toàn bộ đơn hàng (phục vụ thống kê)
  static Future<List<Order>> getAllOrders() async {
    final token = await _storage.read(key: 'token');
    try {
      final res = await _dio.get(
        "/orders/all",
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      final List<dynamic> data = res.data is List ? res.data : res.data['data'];
      return data.map((e) => Order.fromJson(e)).toList();
    } on DioException catch (e) {
      debugPrint("❌ Lỗi lấy toàn bộ đơn hàng: ${e.message}");
      return [];
    }
  }

  // 📊 Xuất thống kê Excel (1 hoặc 3 tháng tuỳ chọn)
  static Future<void> exportMonthlyStatisticsExcel(
      BuildContext context, int monthCount, DateTime startMonth) async {
    final startMonthStr = DateFormat('yyyy-MM').format(startMonth);

    final token = await AuthService.getToken();
    final dio = Dio(BaseOptions(
      baseUrl: AuthService.getBaseUrl(),
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));

    try {
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("❌ Không có quyền ghi file")),
          );
          return;
        }
      }

      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory("/storage/emulated/0/Download");
      } else if (Platform.isWindows || Platform.isMacOS) {
        dir = await getDownloadsDirectory();
      } else if (Platform.isIOS) {
        dir = await getApplicationDocumentsDirectory();
      }

      if (dir == null) throw Exception("Không tìm thấy thư mục lưu file");

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileName = "Thong_ke_${startMonthStr}_${monthCount}thang_$timestamp.xlsx";
      final filePath = "${dir.path}/$fileName";

      debugPrint("🌐 Base URL: ${AuthService.getBaseUrl()}");
      debugPrint("📡 Gọi đến: /orders/export-statistics?start_month=$startMonthStr&months=$monthCount");

      await dio.download(
        "/orders/export-statistics",
        filePath,
        queryParameters: {
          "start_month": startMonthStr,
          "months": monthCount,
        },
        options: Options(
          headers: {
            "Authorization": "Bearer $token",
            "Accept": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
          },
          responseType: ResponseType.bytes,
        ),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            debugPrint("📦 Download progress: ${(received / total * 100).toStringAsFixed(0)}%");
          }
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ Đã tải về: $filePath")),
      );
      await OpenFilex.open(filePath);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Lỗi xuất Excel: $e")),
      );
    }
  }

  // 📊 Xuất thống kê Excel với các tháng tùy chọn
  static Future<void> exportCustomMonthsExcel(
      BuildContext context, List<String> months) async {
    if (months.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Vui lòng chọn ít nhất 1 tháng")),
      );
      return;
    }

    final token = await AuthService.getToken();
    final dio = Dio(BaseOptions(
      baseUrl: AuthService.getBaseUrl(),
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));

    try {
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("❌ Không có quyền ghi file")),
          );
          return;
        }
      }

      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory("/storage/emulated/0/Download");
      } else if (Platform.isWindows || Platform.isMacOS) {
        dir = await getDownloadsDirectory();
      } else if (Platform.isIOS) {
        dir = await getApplicationDocumentsDirectory();
      }

      if (dir == null) throw Exception("Không tìm thấy thư mục lưu file");

      final fileName =
          "Thong_ke_tuy_chon_${DateTime.now().millisecondsSinceEpoch}.xlsx";
      final filePath = "${dir.path}/$fileName";

      final Map<String, dynamic> query = {
        for (int i = 0; i < months.length; i++) "months[$i]": months[i],
      };

      debugPrint("📡 Gọi API /orders/export-statistics");
      debugPrint("🗓️ Các tháng gửi lên: $months");
      debugPrint("🌐 Query thực tế: $query");

      await dio.download(
        "/orders/export-statistics",
        filePath,
        queryParameters: query,
        options: Options(
          headers: {
            "Authorization": "Bearer $token",
            "Accept":
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
          },
          responseType: ResponseType.bytes,
        ),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            debugPrint(
                "📦 Tiến trình tải: ${(received / total * 100).toStringAsFixed(0)}%");
          }
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ Đã tải về: $filePath")),
      );
      await OpenFilex.open(filePath);
    } on DioException catch (e) {
      final msg = e.message ?? "Lỗi không xác định";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Lỗi tải Excel: $msg")),
      );
      debugPrint("❌ Lỗi Dio: ${e.response?.data}");
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Lỗi xuất Excel: $e")),
      );
      debugPrint("❌ Lỗi khác: $e");
    }
  }

  /// 🗑️ Lấy danh sách thùng rác
  static Future<List<Order>> getTrash() async {
    final token = await AuthService.getToken();

    final res = await _dio.get(
      "/orders/trash",
      options: Options(headers: {"Authorization": "Bearer $token"}),
    );

    return (res.data as List).map((json) => Order.fromJson(json)).toList();
  }

  /// ♻️ Khôi phục đơn hàng
  static Future<Order?> restoreOrder(BuildContext context, int orderId) async {
    final token = await AuthService.getToken();

    try {
      final res = await _dio.post(
        "/orders/$orderId/restore",
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Đã khôi phục đơn hàng")),
      );

      return Order.fromJson(res.data['order']);
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("❌ Bạn không có quyền thực hiện hành động này"),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Lỗi: ${e.response?.data['message'] ?? e.message}")),
        );
      }
      return null;
    }
  }

  /// 🔥 Xóa vĩnh viễn
  static Future<bool> forceDeleteOrder(BuildContext context, int orderId) async {
    final token = await AuthService.getToken();

    try {
      await _dio.delete(
        "/orders/$orderId/force-delete",
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🔥 Đã xóa vĩnh viễn")),
      );

      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("❌ Bạn không có quyền thực hiện hành động này"),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Lỗi: ${e.response?.data['message'] ?? e.message}")),
        );
      }
      return false;
    }
  }

  /// 🗑️ Xóa tất cả đơn hàng trong thùng rác
  static Future<bool> emptyTrash(BuildContext context) async {
    final token = await AuthService.getToken();

    try {
      final res = await _dio.delete(
        "/orders/trash/empty",
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      final count = res.data['count'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("🗑️ Đã xóa vĩnh viễn $count đơn hàng khỏi thùng rác"),
          backgroundColor: Colors.orange,
        ),
      );

      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("❌ Bạn không có quyền thực hiện hành động này"),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Lỗi: ${e.response?.data['message'] ?? e.message}")),
        );
      }
      return false;
    }
  }
  /// 🛑 Hoãn đơn hàng
  static Future<void> pauseOrder(
      BuildContext context,
      int orderId,
      String reason,
      ) async {
    try {
      await AuthService.dio.post(
        '/orders/$orderId/pause',
        data: {'reason': reason},
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Đã hoãn đơn hàng'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } on DioException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Lỗi: ${e.message}')),
        );
      }
    }
  }

  /// ▶️ Tiếp tục đơn hàng
  static Future<void> resumeOrder(BuildContext context, int orderId) async {
    try {
      await AuthService.dio.post('/orders/$orderId/resume');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Đã tiếp tục đơn hàng'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on DioException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Lỗi: ${e.message}')),
        );
      }
    }
  }
  /// 📦 Lấy danh sách đơn hàng hoàn thành
  static Future<List<Order>> getCompletedOrders({String? search}) async {
    final token = await AuthService.getToken();

    try {
      final response = await _dio.get( // ✅ ĐỔI dio → _dio
        '/orders/completed',
        queryParameters: search != null ? {'search': search} : null,
        options: Options(headers: {"Authorization": "Bearer $token"}), // ✅ THÊM TOKEN
      );

      return (response.data as List)
          .map((json) => Order.fromJson(json))
          .toList();
    } on DioException catch (e) {
      debugPrint("❌ Lỗi lấy đơn hàng hoàn thành: ${e.message}");
      rethrow;
    }
  }
  /// 🗑️ Xóa 1 đơn hàng hoàn thành
  static Future<bool> deleteCompletedOrder(BuildContext context, int orderId) async {
    final token = await AuthService.getToken();

    try {
      await _dio.delete(
        '/orders/completed/$orderId',
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Đã xóa đơn hàng hoàn thành'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      return true;
    } on DioException catch (e) {
      if (context.mounted) {
        if (e.response?.statusCode == 403) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Chỉ admin mới có quyền xóa'),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Lỗi: ${e.response?.data['message'] ?? e.message}'),
            ),
          );
        }
      }
      return false;
    }
  }

  /// 🗑️ Xóa tất cả đơn hàng hoàn thành
  static Future<bool> deleteAllCompletedOrders(BuildContext context) async {
    final token = await AuthService.getToken();

    try {
      final res = await _dio.delete(
        '/orders/completed/delete-all',
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      final count = res.data['count'] ?? 0;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🗑️ Đã xóa $count đơn hàng hoàn thành'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      return true;
    } on DioException catch (e) {
      if (context.mounted) {
        if (e.response?.statusCode == 403) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Chỉ admin mới có quyền xóa tất cả'),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Lỗi: ${e.response?.data['message'] ?? e.message}'),
            ),
          );
        }
      }
      return false;
    }
  }
}