class Comment {
  final int id;
  final int orderId;
  final int userId;
  final String body;
  final DateTime createdAt;
  final User? user;
  final String? orderNo;

  Comment({
    required this.id,
    required this.orderId,
    required this.userId,
    required this.body,
    required this.createdAt,
    this.user,
    this.orderNo,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    // ✅ PARSE DATETIME ĐÚNG CÁCH - CHUYỂN VỀ LOCAL TIMEZONE
    DateTime parseDateTime(dynamic dateStr) {
      if (dateStr == null || dateStr.toString().isEmpty) {
        return DateTime.now();
      }

      try {
        // Parse ISO string và chuyển về local timezone
        final parsed = DateTime.parse(dateStr.toString());
        return parsed.toLocal(); // ✅ QUAN TRỌNG
      } catch (e) {
        print("❌ Error parsing date: $dateStr - $e");
        return DateTime.now();
      }
    }

    return Comment(
      id: json['id'] ?? 0,
      orderId: json['order_id'] ?? 0,
      userId: json['user_id'] ?? 0,
      body: json['body'] ?? '',
      createdAt: parseDateTime(json['created_at']), // ✅ SỬ DỤNG HÀM PARSE
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      orderNo: json['order_no'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'user_id': userId,
      'body': body,
      'created_at': createdAt.toIso8601String(),
      'user': user?.toJson(),
      'order_no': orderNo,
    };
  }
}

class User {
  final int id;
  final String name;
  final String role;

  User({required this.id, required this.name, required this.role});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      role: json['role'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'role': role,
    };
  }
}