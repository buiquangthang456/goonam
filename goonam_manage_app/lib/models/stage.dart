import 'package:flutter/cupertino.dart';

class Stage {
  final int id;
  final int orderId;
  final int sequence;
  final String name;
  final String status;
  final bool isOverdue;
  final double? remainingDays;
  final DateTime? plannedStart;
  final DateTime? plannedEnd;
  final DateTime? actualStart;
  final DateTime? actualEnd;
  final DateTime? materialRequestDate;
  final String? delayReason;
  final bool isSkipped;
  Stage({
    required this.id,
    required this.orderId,
    required this.sequence,
    required this.name,
    required this.status,
    required this.isOverdue,
    this.remainingDays,
    this.plannedStart,
    this.plannedEnd,
    this.actualStart,
    this.actualEnd,
    this.delayReason,
    this.materialRequestDate,
    required this.isSkipped,
  });

  /// ✅ Safe date parser: xử lý "0", "null", "0000-00-00", datetime ISO, v.v.
  static DateTime? _safeParse(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      final s = value.trim();
      if (s.isEmpty ||
          s == "0" ||
          s == "null" ||
          s == "0000-00-00" ||
          s.startsWith("0000-")) return null;

      try {
        // ✅ Parse bất kỳ định dạng nào: ISO 8601, date-only, datetime
        final parsed = DateTime.parse(s);
        return parsed.toLocal(); // ← GIỮ NGUYÊN DATETIME, KHÔNG CHỈ LẤY NGÀY
      } catch (e) {
        debugPrint("⚠️ Lỗi parse datetime: $s - Error: $e");
        return null;
      }
    }
    return null;
  }

  factory Stage.fromJson(Map<String, dynamic> json) {
    return Stage(
      id: json['id'] ?? 0,
      orderId: json['order_id'] ?? 0,
      sequence: json['sequence'] ?? 0,
      name: json['name'] ?? '',
      status: json['status'] ?? '',
      isOverdue: json['is_overdue'] == true ||
          json['is_overdue'] == 1 ||
          json['is_overdue'] == "1",
      remainingDays: json['remaining_days'] != null
          ? double.tryParse(json['remaining_days'].toString())
          : null,
      plannedStart: _safeParse(json['planned_start']),
      plannedEnd: _safeParse(json['planned_end']),
      actualStart: _safeParse(json['actual_start']),
      actualEnd: _safeParse(json['actual_end']),
      delayReason: json['delay_reason'],
      materialRequestDate: _safeParse(json['material_request_date']),
      isSkipped: json['is_skipped'] == true ||
          json['is_skipped'] == 1 ||
          json['is_skipped'] == "1",
    );
  }

  /// ✅ toJson() đồng bộ với OrderFormPage gửi lên API
  Map<String, dynamic> toJson() {
    String? _formatDate(DateTime? dt) =>
        dt == null ? null : dt.toIso8601String();

    return {
      'id': id,
      'order_id': orderId,
      'sequence': sequence,
      'name': name,
      'status': status,
      'is_overdue': isOverdue,
      'remaining_days': remainingDays,
      'planned_start': _formatDate(plannedStart),
      'planned_end': _formatDate(plannedEnd),
      'actual_start': _formatDate(actualStart),
      'actual_end': _formatDate(actualEnd),
      'delay_reason': delayReason,
      'material_request_date': _formatDate(materialRequestDate),
      'is_skipped': isSkipped,
    };
  }
}
