import 'dart:async';

import 'package:flutter/material.dart';
import 'package:goonam_manage_app/pages/stage_service.dart';
import 'package:intl/intl.dart';
import '../models/comment.dart';
import '../models/order.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import 'package:month_year_picker/month_year_picker.dart';
import '../services/comment_service.dart';
import '../services/realtime_service.dart';

class OrderDetailPage extends StatefulWidget {
  final int orderId;
  final String initialTab;
  final int? commentId;

  const OrderDetailPage({
    super.key,
    required this.orderId,
    this.initialTab = "timeline",
    this.commentId,
  });

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late StreamSubscription _commentSub;
  bool loading = true;
  Order? order;
  String? userRole;
  int? highlightedCommentId;
  bool downloading = false;
  String translateStatus(String status) {
    switch (status) {
      case 'pending':
        return 'Chờ xử lý';
      case 'in_progress':
        return 'Đang sản xuất';
      case 'done':
        return 'Hoàn thành';
      case 'late':
        return 'Trễ hạn';
      default:
        return status;
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // ✅ Khi chuyển sang tab "Bình luận", gọi API đánh dấu đã đọc
    _tabController.addListener(() async {
      if (_tabController.index == 1 && !_tabController.indexIsChanging) {
        await CommentService.markOrderCommentsAsRead(widget.orderId);
      }
    });

    if (widget.initialTab == "comments") {
      _tabController.index = 1;
    }

    highlightedCommentId = widget.commentId;
    fetchOrderDetail();
    fetchUserRole();
    _commentSub = RealtimeService.commentStream.listen((data) {
      final orderId = data['order_id'];
      if (orderId == widget.orderId && mounted) {
        setState(() {
          order?.comments.insert(0, Comment.fromJson(data['comment']));
        });
      }
    });
  }

  Future<void> fetchOrderDetail() async {
    try {
      final result = await OrderService.getOrderDetail(widget.orderId);
      setState(() {
        order = result;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi tải đơn hàng: $e")),
      );
    }
  }

  Future<void> fetchUserRole() async {
    final u = await AuthService.getStoredUser();
    setState(() {
      userRole = u?['role'];
    });
  }

  @override
  void dispose() {
    _commentSub.cancel();
    _tabController.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    if (loading || userRole == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (order == null) {
      return const Scaffold(
        body: Center(child: Text("Không tìm thấy đơn hàng")),
      );
    }

    final isStaff = userRole == 'staff';

    return DefaultTabController(
      length: 2, // 🔥 luôn có 2 tab cho tất cả role
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context, true); // ✅ Trả về true
            },
          ),
          title: order == null
              ? const Text("Đang tải...")
              : Row(
            children: [
              const Icon(Icons.folder_open, size: 20, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${order!.projectName} (${order!.orderNo}${order!.companyName != null && order!.companyName!.isNotEmpty ? ', ${order!.companyName}' : ''})",
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            // ✅ THÊM NÚT HOÃN/TIẾP TỤC (CHỈ HIỆN VỚI ADMIN/MANAGER/DIRECTOR)
            if (userRole != 'staff')
              order?.isPaused == true
                  ? IconButton(
                icon: const Icon(Icons.play_arrow, color: Colors.green),
                tooltip: "Tiếp tục đơn hàng",
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text("Tiếp tục đơn hàng"),
                      content: const Text(
                          "Bạn có chắc muốn tiếp tục đơn hàng này?"),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text("Hủy"),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text("Tiếp tục"),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await OrderService.resumeOrder(context, order!.id);
                    await fetchOrderDetail(); // Reload
                  }
                },
              )
                  : IconButton(
                icon: const Icon(Icons.pause, color: Colors.orange),
                tooltip: "Hoãn đơn hàng",
                onPressed: () async {
                  final ctrl = TextEditingController();
                  final reason = await showDialog<String>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text("Hoãn đơn hàng"),
                      content: TextField(
                        controller: ctrl,
                        decoration: const InputDecoration(
                          labelText: "Lý do hoãn",
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("Hủy"),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange),
                          onPressed: () {
                            final text = ctrl.text.trim();
                            if (text.isEmpty) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        "Vui lòng nhập lý do hoãn!")),
                              );
                            } else {
                              Navigator.pop(ctx, text);
                            }
                          },
                          child: const Text("Hoãn"),
                        ),
                      ],
                    ),
                  );

                  if (reason != null && reason.isNotEmpty) {
                    await OrderService.pauseOrder(
                        context, order!.id, reason);
                    await fetchOrderDetail(); // Reload
                  }
                },
              ),
            IconButton(
              tooltip: "Xuất file đơn hàng",
              icon: downloading
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.redAccent, // 🔴 Đổi màu loading sang đỏ
                ),
              )
                  : const Icon(Icons.download_rounded, color: Colors.redAccent), // giữ màu icon đồng bộ
              onPressed: downloading
                  ? null
                  : () async {
                setState(() => downloading = true);

                final fileName =
                    "order_${order!.orderNo}_${DateTime.now().millisecondsSinceEpoch}";

                await OrderService.exportOrderExcel(context, order!.id, fileName);

                if (mounted) setState(() => downloading = false);
              },
            ),

          ],

          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: "Tiến độ"),
              Tab(text: "Bình luận"),
              Tab(text: "Lịch sử chỉnh sửa"),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildTimeline(),
            _buildComments(),
            _buildHistory(),// _buildComments() đã có ẩn thêm/sửa/xóa cho staff
          ],
        ),
      ),
    );
  }

  /// HIỂN THỊ TIMELINE
  Widget _buildTimeline() {
    if (order?.stages == null || order!.stages.isEmpty) {
      return const Center(child: Text("Chưa có công đoạn"));
    }
    return Column(
        children: [
        // ✅ HIỂN THỊ BANNER KHI ĐƠN HÀNG BỊ HOÃN
        if (order?.isPaused == true)
    Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.orange.shade100,
      child: Row(
        children: [
          const Icon(Icons.pause_circle, color: Colors.orange, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "🛑 Đơn hàng đang bị hoãn",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.orange,
                  ),
                ),
                if (order!.pauseReason != null)
                  Text(
                    "Lý do: ${order!.pauseReason}",
                    style: const TextStyle(fontSize: 14),
                  ),
                if (order!.pausedAt != null)
                  Text(
                    "Hoãn lúc: ${DateFormat('dd/MM/yyyy HH:mm').format(order!.pausedAt!)}",
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black54),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
    Expanded(
        child: ListView.separated(
        itemCount: order!.stages.length + 1,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (context, index) {
        // ✅ Hiển thị dòng thông tin công ty ở đầu danh sách
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Công ty: ${order!.companyName ?? '-'}",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  "Dự án: ${order!.projectName}",
                  style: const TextStyle(color: Colors.black54),
                ),
                const Divider(),
              ],
            ),
          );
        }
        final s = order!.stages[index-1];
        IconData icon;
        Color color;

        if (s.status == 'done') {
          icon = Icons.check_circle;
          color = Colors.green;
        } else {
          // ✅ Kiểm tra trễ dựa trên NGÀY, không tính giờ
          bool isLate = false;

          if (s.plannedEnd != null) {
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final deadline = DateTime(
              s.plannedEnd!.year,
              s.plannedEnd!.month,
              s.plannedEnd!.day,
            );

            // ✅ Chỉ báo trễ khi ngày hiện tại > ngày deadline
            // VÍ DỤ:
            // - today = 03/12/2025, deadline = 03/12/2025 → KHÔNG TRỄ ✅
            // - today = 04/12/2025, deadline = 03/12/2025 → TRỄ ❌
            isLate = today.millisecondsSinceEpoch > deadline.millisecondsSinceEpoch;
          }

          if (isLate) {
            icon = Icons.error;
            color = Colors.red;
          } else if (s.status == 'in_progress') {
            icon = Icons.play_circle_fill;
            color = Colors.blue;
          } else {
            icon = Icons.access_time;
            color = Colors.orange;
          }
        }

        return ListTile(
          leading: Icon(icon, color: color),
          title: Text(s.name ?? ""),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (s.plannedStart != null)
                Text("Bắt đầu: ${DateFormat('dd/MM/yyyy').format(s.plannedStart!)}"),
              if (s.plannedEnd != null)
                Text("Kết thúc: ${DateFormat('dd/MM/yyyy').format(s.plannedEnd!)}"),
              if (s.actualEnd != null)
                Text("Hoàn thành: ${DateFormat('dd/MM/yyyy').format(s.actualEnd!)}"),
              if (s.remainingDays != null)
                Text("Còn lại: ${s.remainingDays}"),
              Text("Trạng thái: ${translateStatus(s.status)}"),

              // 🔹 Hiển thị ngày yêu cầu vật tư — chỉ công đoạn đầu tiên có
              if ((s.sequence ?? 0) == 1 && s.materialRequestDate != null)
                Text(
                  "Yêu cầu vật tư: ${DateFormat('dd/MM/yyyy').format(s.materialRequestDate!)}",
                  style: const TextStyle(color: Colors.deepPurple),
                ),

              // ✅ Banner hiển thị lý do gia hạn - CHỈ KHI THỰC SỰ GIA HẠN
              if (s.delayReason != null &&
                  s.delayReason!.isNotEmpty &&
                  s.delayReason != 'Chưa nhập lý do') // ← Thêm điều kiện này
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: s.status == 'done'
                        ? Colors.green.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: s.status == 'done'
                          ? Colors.green.shade300
                          : Colors.orange.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        s.status == 'done' ? Icons.check_circle : Icons.info_outline,
                        color: s.status == 'done' ? Colors.green : Colors.orange,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s.status == 'done'
                              ? "✅ Đã hoàn thành (Có gia hạn): ${s.delayReason}"
                              : "📝 Đã gia hạn: ${s.delayReason}",
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ✅ Nút đánh dấu hoàn thành
              IconButton(
                icon: Icon(
                  s.status == "done" ? Icons.check_circle : Icons.check_circle_outline,
                  color: s.status == "done" ? Colors.green : Colors.grey,
                ),
                  onPressed: () async {
                    final updated = await StageService.markDone(context, order!.id, s.id);
                    if (updated != null) {
                      // ✅ Cập nhật stage trong bộ nhớ
                      setState(() {
                        order!.stages[index - 1] = updated;
                      });

                      // ✅ Reload toàn bộ đơn để đồng bộ timeline + trạng thái
                      final refreshed = await OrderService.getOrderDetail(order!.id);

                      setState(() => order = refreshed);

                      // 🔥 Kiểm tra trạng thái đơn hàng TRỰC TIẾP từ backend
                      if (refreshed.status == 'completed') {
                        // Đơn hàng đã hoàn thành thực sự
                        if (mounted) Navigator.pop(context, true);
                      }
                    }
                  }
              ),

              // 🕒 Nút chỉnh thời gian công đoạn — chỉ hiện nếu KHÔNG phải staff
              if (userRole != 'staff')
                IconButton(
                  icon: const Icon(Icons.edit_calendar, color: Colors.purple),
                  tooltip: "Thiết lập ngày bắt đầu / kết thúc",
                  onPressed: () async {
                    // 🗓️ Chọn ngày bắt đầu
                    final pickedStart = await showDatePicker(
                      context: context,
                      initialDate: s.plannedStart ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (pickedStart == null) return;

                    // Nhập số ngày
                    int? days = await showDialog<int>(
                      context: context,
                      builder: (ctx) {
                        final ctrl = TextEditingController();
                        return AlertDialog(
                          title: const Text("Nhập số ngày công đoạn"),
                          content: TextField(
                            controller: ctrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Số ngày",
                              border: OutlineInputBorder(),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text("Hủy"),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                final val = int.tryParse(ctrl.text);
                                Navigator.pop(ctx, val);
                              },
                              child: const Text("OK"),
                            ),
                          ],
                        );
                      },
                    );

                    if (days == null || days <= 0) return;

                    // ✅ Tính ngày kết thúc
                    final plannedEnd = pickedStart.add(Duration(days: days - 1));

                    // Gọi API cập nhật
                    // 🔹 Hỏi lý do gia hạn trước khi lưu
                    final reason = await showDialog<String>(
                      context: context,
                      builder: (ctx) {
                        final ctrl = TextEditingController();
                        return AlertDialog(
                          title: const Text("Nhập lý do gia hạn"),
                          content: TextField(
                            controller: ctrl,
                            decoration: const InputDecoration(
                              labelText: "Lý do",
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 3,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text("Hủy"),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                final val = ctrl.text.trim();
                                if (val.isEmpty) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text("Vui lòng nhập lý do gia hạn!"),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                } else {
                                  Navigator.pop(ctx, val);
                                }
                              },
                              child: const Text("Lưu"),
                            ),
                          ],
                        );
                      },
                    );

                    // ❌ Nếu không nhập lý do thì dừng lại
                    if (reason == null || reason.isEmpty) return;

                    // ✅ Gọi API cập nhật ngày & lý do cùng lúc
                    final updated = await StageService.updateStageTime(
                      context,
                      order!.id,
                      s.id,
                      pickedStart,
                      plannedEnd,
                      delayReason: reason, // Thêm tham số lý do
                    );

                    if (updated != null) {
                      setState(() {
                        order!.stages[index - 1] = updated;
                      });

                      // ✅ Reload lại toàn bộ đơn để đồng bộ
                      final refreshed = await OrderService.getOrderDetail(order!.id);
                      if (mounted) setState(() => order = refreshed);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "Đã gia hạn: ${DateFormat('dd/MM/yyyy').format(pickedStart)} → ${DateFormat('dd/MM/yyyy').format(plannedEnd)}\nLý do: $reason",
                          ),
                          backgroundColor: Colors.orangeAccent,
                        ),
                      );
                    }
                  },

                ),
              // 📝 Nút nhập lý do trễ
              // 📝 Nút nhập lý do trễ - CHỈ HIỆN KHI THỰC SỰ TRỄ
              if (userRole != 'staff' && (() {
                // ✅ Kiểm tra trễ dựa trên NGÀY
                if (s.plannedEnd != null && s.status != 'done') {
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final deadline = DateTime(
                    s.plannedEnd!.year,
                    s.plannedEnd!.month,
                    s.plannedEnd!.day,
                  );

                  // ✅ Chỉ hiện nút khi ngày hiện tại > ngày deadline
                  return today.difference(deadline).inDays > 0;
                }
                return false;
              })())
                IconButton(
                  icon: const Icon(Icons.feedback_outlined, color: Colors.redAccent),
                  tooltip: "Nhập lý do trễ",
                  onPressed: () async {
                    final ctrl = TextEditingController(text: s.delayReason ?? "");
                    final reason = await showDialog<String>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text("Nhập lý do trễ"),
                        content: TextField(
                          controller: ctrl,
                          decoration: const InputDecoration(
                            labelText: "Nguyên nhân trễ",
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                            child: const Text("Lưu"),
                          ),
                        ],
                      ),
                    );

                    if (reason != null && reason.isNotEmpty) {
                      final updated = await StageService.updateDelayReason(
                        context,
                        order!.id,
                        s.id,
                        reason,
                      );

                      if (updated != null) {
                        await Future.delayed(const Duration(milliseconds: 120));

                        if (mounted) {
                          setState(() {
                            order!.stages[index - 1] = updated;
                          });
                        }

                        final refreshed = await OrderService.getOrderDetail(order!.id);
                        if (mounted) setState(() => order = refreshed);
                      }
                    }
                  },
                ),
            ],
          ),
        );
        },
        ),
    ),
        ],
    ); // ✅ ĐÓNG Column
  }

  /// HIỂN THỊ COMMENTS
  /// HIỂN THỊ COMMENTS
  Widget _buildComments() {
    final comments = order?.comments ?? [];
    final TextEditingController _commentCtrl = TextEditingController();

    return FutureBuilder<Map<String, dynamic>?>(
      future: AuthService.getStoredUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Lỗi load user: ${snapshot.error}"));
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return const Center(child: Text("Không có dữ liệu user"));
        }

        final currentUser = snapshot.data!;
        final currentRole = currentUser['role'] ?? 'guest';
        final currentUserId = currentUser['id'];

        final isStaff = currentRole == 'staff';

        return Column(
          children: [
            // 🔹 Danh sách comment
            Expanded(
              child: comments.isEmpty
                  ? const Center(child: Text("Chưa có bình luận"))
                  : ListView.builder(
                itemCount: comments.length,
                itemBuilder: (context, index) {
                  final c = comments[index];

                  // 🔸 Chỉ admin/manager/director hoặc chủ comment được chỉnh sửa
                  final canModify = c.userId == currentUserId;

                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(c.user?.name ?? "Ẩn danh"),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.body),
                        Text(
                          DateFormat('dd/MM/yyyy HH:mm').format(c.createdAt),
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    trailing: canModify
                        ? PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == "edit") {
                          final newBody =
                          await showDialog<String>(
                            context: context,
                            builder: (ctx) {
                              final ctrl = TextEditingController(
                                  text: c.body);
                              return AlertDialog(
                                title: const Text("Sửa bình luận"),
                                content: TextField(
                                  controller: ctrl,
                                  decoration:
                                  const InputDecoration(
                                    border: OutlineInputBorder(),
                                  ),
                                  maxLines: 3,
                                ),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx),
                                      child: const Text("Hủy")),
                                  ElevatedButton(
                                      onPressed: () => Navigator.pop(
                                          ctx, ctrl.text.trim()),
                                      child: const Text("Lưu")),
                                ],
                              );
                            },
                          );

                          if (newBody != null && newBody.isNotEmpty) {
                            final updated =
                            await OrderService.updateComment(
                                context,
                                order!.id,
                                c.id,
                                newBody);
                            if (updated != null) {
                              setState(() {
                                order!.comments[index] =
                                    Comment.fromJson(updated);
                              });
                            }
                          }
                        } else if (value == "delete") {
                          final confirm =
                          await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text("Xóa bình luận"),
                              content: const Text(
                                  "Bạn có chắc muốn xóa bình luận này?"),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, false),
                                    child: const Text("Hủy")),
                                ElevatedButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, true),
                                    child: const Text("Xóa")),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            await OrderService.deleteComment(
                                context, order!.id, c.id);
                            setState(() {
                              order!.comments.removeAt(index);
                            });
                          }
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                            value: "edit", child: Text("Sửa")),
                        PopupMenuItem(
                            value: "delete", child: Text("Xóa")),
                      ],
                    )
                        : null,
                  );
                },
              ),
            ),

            // 🔹 Ô nhập bình luận (staff vẫn được phép comment)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentCtrl,
                        decoration: const InputDecoration(
                          hintText: "Nhập bình luận...",
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (text) async {
                          final content = text.trim();
                          if (content.isEmpty) return;

                          final newCmt = await OrderService.addComment(context, order!.id, content);
                          if (newCmt != null) {
                            setState(() {
                              order!.comments.insert(0, Comment.fromJson(newCmt));
                            });
                            _commentCtrl.clear();
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, color: Colors.blue),
                      onPressed: () async {
                        final text = _commentCtrl.text.trim();
                        if (text.isEmpty) return;

                        final newCmt = await OrderService.addComment(context, order!.id, text);
                        if (newCmt != null) {
                          setState(() {
                            order!.comments.insert(0, Comment.fromJson(newCmt));
                          });
                          _commentCtrl.clear();
                        }
                      },
                    )
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
  /// HIỂN THỊ LỊCH SỬ CHỈNH SỬA
  Widget _buildHistory() {
    final history = order?.history ?? [];

    if (history.isEmpty) {
      return const Center(child: Text("Chưa có lịch sử chỉnh sửa"));
    }

    return ListView.builder(
      itemCount: history.length,
      itemBuilder: (context, index) {
        final h = history[index];
        final isAdminEdit = h.changeMode == "admin_edit";
        final color = isAdminEdit ? Colors.orange.shade700 : Colors.blueGrey.shade700;
        final bgColor = isAdminEdit ? Colors.orange.shade50 : Colors.blueGrey.shade50;
        final icon = isAdminEdit ? Icons.admin_panel_settings : Icons.history;

        final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(h.date);

        return Card(
          color: bgColor,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ListTile(
            leading: Icon(icon, color: color, size: 28),
            title: Text(
              h.change,
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Người chỉnh: ${h.editor}", style: const TextStyle(fontSize: 13)),
                if (h.note != null && h.note!.isNotEmpty)
                  Text("Ghi chú: ${h.note}", style: const TextStyle(fontSize: 13)),
                Text(
                  "Ngày: $formattedDate",
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


}
