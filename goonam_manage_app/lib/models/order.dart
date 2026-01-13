import 'stage.dart';
import 'comment.dart';

class Order {
  final int id;
  final String orderNo;
  final String projectName;
  final String? companyName;
  final String orderType;
  final String? description;
  final int quantity;
  final DateTime orderDate;
  final DateTime deliveryDate;
  final DateTime? originalDeliveryDate;
  final DateTime? actualEnd;
  final String status; // trạng thái hiện tại
  final String overallStatus; // tổng quan: in_progress / late / done
  final int highlightFlag;
  final String? timeBudgetDays; // đổi sang String để dễ hiển thị
  final String? remainingDays; // đổi sang String để dễ hiển thị
  final List<Stage> stages;
  final List<Comment> comments;
  final List<EditHistory> history; // lịch sử chỉnh sửa đơn hàng
  final List<dynamic>? adminEditLogs; // ghi lại log chỉnh sửa của admin
  final DateTime? deletedAt;
  final bool isPaused;
  final String? pauseReason;
  final DateTime? pausedAt;
  final DateTime? completedAt;
  final Map<String, dynamic>? latestComment;
  final int unreadCommentsCount;
  Order({
    required this.id,
    required this.orderNo,
    required this.projectName,
    this.companyName,
    required this.orderType,
    this.description,
    required this.quantity,
    required this.orderDate,
    required this.deliveryDate,
    this.originalDeliveryDate,
    this.actualEnd,
    required this.status,
    required this.overallStatus,
    required this.highlightFlag,
    this.timeBudgetDays,
    this.remainingDays,
    required this.stages,
    this.comments = const [],
    this.history = const [],
    this.adminEditLogs,
    this.deletedAt,
    this.isPaused = false,
    this.pauseReason,
    this.pausedAt,
    this.completedAt,
    this.latestComment,
    this.unreadCommentsCount = 0,
  });

  /// ✅ Parse từ JSON và KHÔNG bị lệch ngày (giữ nguyên theo local VN)
  factory Order.fromJson(Map<String, dynamic> json) {
    // ✅ HÀM CŨ: Parse ngày (chỉ lấy yyyy-MM-dd, bỏ giờ)
    DateTime _parseLocalDate(String? s) {
      if (s == null || s.trim().isEmpty || s == "0" || s.toLowerCase() == "null") {
        return DateTime.now();
      }
      try {
        if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) {
          final parts = s.split('-');
          return DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
        }

        final parsed = DateTime.parse(s);
        final local = parsed.toLocal();
        return DateTime(local.year, local.month, local.day);
      } catch (e) {
        return DateTime.now();
      }
    }

    // ✅ HÀM MỚI: Parse datetime (giữ nguyên giờ + timezone)
    DateTime? _parseDateTime(String? s) {
      if (s == null || s.trim().isEmpty || s == "0" || s.toLowerCase() == "null") {
        return null;
      }
      try {
        final parsed = DateTime.parse(s); // Parse (tự động về UTC)
        return parsed.toLocal(); // ✅ CHUYỂN VỀ LOCAL TIMEZONE
      } catch (e) {
        return null;
      }
    }

    return Order(
      id: json['id'] ?? 0,
      orderNo: json['order_no'] ?? '',
      projectName: json['project_name'] ?? '',
      companyName: json['company_name'],
      orderType: json['order_type'] ?? '',
      description: json['description'],
      quantity: json['quantity'] is int
          ? json['quantity']
          : int.tryParse(json['quantity']?.toString() ?? '0') ?? 0,
      orderDate: _parseLocalDate(json['order_date']),
      deliveryDate: _parseLocalDate(json['delivery_date']),
      originalDeliveryDate: json['original_delivery_date'] != null
          ? _parseLocalDate(json['original_delivery_date'])
          : null,
      actualEnd: json['actual_end'] != null
          ? _parseLocalDate(json['actual_end'])
          : null,
      status: json['status'] ?? '',
      overallStatus: json['overall_status'] ?? '',
      highlightFlag: json['highlight_flag'] is int
          ? json['highlight_flag']
          : int.tryParse(json['highlight_flag']?.toString() ?? '0') ?? 0,
      timeBudgetDays: json['time_budget_days']?.toString(),
      remainingDays: json['remaining_days']?.toString(),
      stages: (json['stages'] is List)
          ? (json['stages'] as List)
          .map((e) => Stage.fromJson(e as Map<String, dynamic>))
          .toList()
          : [],
      comments: (json['comments'] as List<dynamic>?)
          ?.map((e) => Comment.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      history: (json['history'] as List<dynamic>?)
          ?.map((e) => EditHistory.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      adminEditLogs: json['admin_edit_logs'] ?? [],
      deletedAt:  _parseDateTime(json['deleted_at']),
      isPaused: json['is_paused'] ?? false,
      pauseReason: json['pause_reason'],
      pausedAt: json['paused_at'] != null
          ? _parseDateTime(json['paused_at']) // ✅ DÙNG HÀM MỚI
          : null,
      completedAt: _parseDateTime(json['completed_at']),
      // ✅ THÊM DÒNG NÀY
      latestComment: json['latest_comment'] as Map<String, dynamic>?,
      unreadCommentsCount: json['unread_comments_count'] ?? 0,
    );
  }

  /// ✅ Gửi ngược về backend: luôn theo dạng yyyy-MM-dd (đúng chuẩn Laravel)
  Map<String, dynamic> toJson() {
    String _formatDate(DateTime d) =>
        "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

    return {
      'id': id,
      'order_no': orderNo,
      'project_name': projectName,
      'company_name': companyName,
      'order_type': orderType,
      'description': description,
      'quantity': quantity,
      'order_date': _formatDate(orderDate),
      'delivery_date': _formatDate(deliveryDate),
      'original_delivery_date': originalDeliveryDate != null
          ? _formatDate(originalDeliveryDate!)
          : null,
      'actual_end': actualEnd != null ? _formatDate(actualEnd!) : null,
      'status': status,
      'overall_status': overallStatus,
      'highlight_flag': highlightFlag,
      'time_budget_days': timeBudgetDays,
      'remaining_days': remainingDays,
      'stages': stages.map((s) => s.toJson()).toList(),
      'comments': comments.map((c) => c.toJson()).toList(),
      'history': history.map((h) => h.toJson()).toList(),
      'admin_edit_logs': adminEditLogs,
      'is_paused': isPaused,
      'pause_reason': pauseReason,
      'paused_at': pausedAt?.toIso8601String(),
    };
  }
}

/// ✅ Lớp ghi lại lịch sử chỉnh sửa đơn hàng
class EditHistory {
  final String editor;
  final String change;
  final DateTime date;
  final String? changeMode; // admin_edit, manual, system
  final String? note; // ghi chú tùy chọn

  EditHistory({
    required this.editor,
    required this.change,
    required this.date,
    this.changeMode,
    this.note,
  });

  factory EditHistory.fromJson(Map<String, dynamic> json) {
    DateTime _parseLocal(String? s) {
      if (s == null || s.isEmpty) return DateTime.now();
      try {
        final parsed = DateTime.tryParse(s);
        if (parsed == null) return DateTime.now();
        final local = parsed.toLocal();
        return DateTime(local.year, local.month, local.day);
      } catch (e) {
        return DateTime.now();
      }
    }

    return EditHistory(
      editor: json['editor'] ?? 'Không rõ',
      change: json['change'] ?? '',
      date: _parseLocal(json['date']),
      changeMode: json['change_mode'],
      note: json['note'],
    );
  }

  Map<String, dynamic> toJson() {
    String _formatDate(DateTime d) =>
        "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

    return {
      'editor': editor,
      'change': change,
      'date': _formatDate(date),
      'change_mode': changeMode,
      'note': note,
    };
  }
}

