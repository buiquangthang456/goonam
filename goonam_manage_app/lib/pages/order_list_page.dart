import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:goonam_manage_app/pages/trash_page.dart';
import '../main.dart';
import '../models/order.dart';
import '../services/notification_helper.dart';
import '../services/order_service.dart';
import '../services/auth_service.dart';
import 'completed_orders_page.dart';
import 'order_detail_page.dart';
import 'order_form_page.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:month_year_picker/month_year_picker.dart';
import 'package:goonam_manage_app/pages/theme.dart';
import 'stage_service.dart';
import '../services/comment_service.dart';
import 'dart:async'; // để dùng Timer

class OrderListPage extends StatefulWidget {
  const OrderListPage({super.key});

  @override
  State<OrderListPage> createState() => _OrderListPageState();
}

class _OrderListPageState extends State<OrderListPage> {
  List<Order> orders = [];
  List<Order> doorOrders = []; // 🔹 Đơn hàng loại Cửa
  List<Order> metalOrders = []; // 🔹 Đơn hàng loại Kim loại

  // ✅ THÊM CÁC BIẾN PAGINATION
  int currentPage = 1;
  int totalPages = 1;
  bool hasMoreData = false;
  bool isLoadingMore = false;



  int countAll = 0;
  int countInProgress = 0;
  int countLate = 0;
  int countCompleted = 0;
  bool loading = true;
  bool silentRefresh = false;
  int unreadComments = 0;
  List<Map<String, dynamic>> unreadOrders = [];
  Timer? _commentTimer;

  Map<String, dynamic>? user;
  final TextEditingController _searchController = TextEditingController();

  String _filterStatus = "all"; // 🔥 all / in_progress / late / completed

  @override
  void initState() {
    super.initState();
    fetchOrders();
    fetchUser();
    _loadUnreadComments();
    _commentTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadUnreadComments();
    });
  }

  Future<void> _loadUnreadComments() async {
    try {
      final data = await CommentService.getUnreadComments();

      if (mounted) {
        setState(() {
          unreadComments = data['unread_total'] ?? 0; // ✅ đúng key từ API
          unreadOrders = List<Map<String, dynamic>>.from(data['orders'] ?? []);
        });

        // ✅ Cập nhật badge global (nếu bạn muốn hiển thị realtime ở icon)
        GlobalBadge.unreadComments.value = unreadComments;
      }
    } catch (e) {
      debugPrint("⚠️ Lỗi load unread comments: $e");
    }
  }
  void showUnreadCommentsModal(BuildContext parentContext) {
    showModalBottomSheet(
      context: parentContext,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "💬 Bình luận chưa đọc",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: unreadOrders.isEmpty
                    ? const Center(child: Text("Không có bình luận mới."))
                    : ListView.builder(
                  itemCount: unreadOrders.length,
                  itemBuilder: (context, index) {
                    final o = unreadOrders[index];
                    return ListTile(
                      // ✅ THÊM AVATAR CHỮ CÁI ĐẦU
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: Text(
                          (o['user_name'] ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),

                      // ✅ GIỮ NGUYÊN TITLE
                      title: Text(
                        "${o['project_name']} (${o['order_no']})",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),

                      // ✅ THÊM TÊN USER VÀO SUBTITLE
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "👤 ${o['user_name'] ?? 'Unknown'}",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            o['body'] ?? "-",
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      onTap: () async {
                        Navigator.pop(ctx); // đóng modal
                        final orderId = o['order_id'];
                        if (orderId == null || orderId == 0) {
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            const SnackBar(content: Text("⚠️ Không tìm thấy ID đơn hàng hợp lệ")),
                          );
                          return;
                        }

                        // 🟩 Gọi API đánh dấu đã đọc
                        await CommentService.markOrderCommentsAsRead(orderId);

                        // ✅ Cập nhật ngay trên UI (không cần đợi 5 giây)
                        if (mounted) {
                          setState(() {
                            unreadOrders.removeWhere((e) => e['order_id'] == orderId);
                            unreadComments = unreadOrders.length;
                          });
                          GlobalBadge.unreadComments.value = unreadComments;
                        }

                        // 🟩 Gọi API đánh dấu đã đọc (không chờ để giữ tốc độ)
                        unawaited(CommentService.markOrderCommentsAsRead(orderId));

                        // ✅ Cập nhật UI tức thì — xóa khỏi danh sách local
                        if (mounted) {
                          setState(() {
                            unreadOrders.removeWhere((e) => e['order_id'] == orderId);
                            unreadComments = unreadOrders.length;
                          });
                          GlobalBadge.unreadComments.value = unreadComments;
                        }

                        // 🟩 Dùng parentContext để điều hướng
                        await Navigator.push(
                          parentContext,
                          MaterialPageRoute(
                            builder: (_) => OrderDetailPage(
                              orderId: orderId,
                              initialTab: "comments",
                            ),
                          ),
                        );

                        // 🟩 Sau khi quay lại, vẫn gọi lại để đồng bộ với backend
                        await _loadUnreadComments();

                      },
                    );
                  },
                ),
              ),
              if (unreadOrders.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.mark_chat_read),
                    label: const Text("Đánh dấu tất cả là đã đọc"),
                    onPressed: () async {
                      await CommentService.markAllAsRead();
                      Navigator.pop(ctx);
                      await _loadUnreadComments();
                      ScaffoldMessenger.of(parentContext).showSnackBar(
                        const SnackBar(content: Text("✅ Đã đánh dấu tất cả là đã đọc.")),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }


  Future<void> fetchOrders({String? search, int page = 1, bool silent = false}) async {
    try {
      // ✅ Nếu là silent refresh (sau khi xóa) → KHÔNG hiển thị loading
      if (silent) {
        // Không set loading = true
      } else if (page == 1) {
        setState(() => loading = true);
      } else {
        setState(() => isLoadingMore = true);
      }

      // ✅ Lấy response đầy đủ (không chỉ list)
      final response = await OrderService.getOrdersWithMeta(search: search, page: page);
      final list = response['data'] as List<Order>;
      final meta = response['meta'] as Map<String, dynamic>?;

      // ✅ LOG 1: Số đơn từ API


      setState(() {
        List<Order> filtered = list;



        // Lọc theo trạng thái
        if (_filterStatus == "in_progress") {
          filtered = list.where((o) => o.overallStatus == "in_progress").toList();
        } else if (_filterStatus == "late") {
          filtered = list.where((o) => o.overallStatus == "late").toList();
        } else if (_filterStatus == "completed") {
          filtered = list.where(
                  (o) =>
              o.status == "completed" ||
                  o.overallStatus == "completed_early" ||
                  o.overallStatus == "completed_late" ||
                  o.overallStatus == "done"
          ).toList();
        }



        // Tính số lượng từng loại
        countAll = list.length;
        countInProgress = list.where((o) => o.overallStatus == "in_progress").length;
        countLate = list.where((o) => o.overallStatus == "late").length;
        countCompleted = list.where((o) => o.overallStatus == "done" || o.status == "completed").length;

        // Hàm parse số ngày
        double parseRemainingDays(String? text) {
          if (text == null || text.isEmpty) return double.infinity;
          final regex = RegExp(r'(-?\d+) ngày');
          final match = regex.firstMatch(text);
          if (match != null) {
            return double.tryParse(match.group(1) ?? '0') ?? double.infinity;
          }
          return double.infinity;
        }

        // Sắp xếp
        filtered.sort((a, b) {
          int getPriority(Order order) {
            // ✅ Kiểm tra xem đơn hàng có trễ không (dựa vào deliveryDate và trạng thái)
            bool isLate = false;

            // TH1: overallStatus báo trễ
            if (order.overallStatus == 'late') {
              isLate = true;
            }

            // TH2: Đơn chưa hoàn thành + đã quá ngày giao
            if (order.status != 'completed' &&
                order.overallStatus != 'done' &&
                order.overallStatus != 'completed_early' &&
                order.overallStatus != 'completed_late') {

              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final deliveryDay = DateTime(
                order.deliveryDate.year,
                order.deliveryDate.month,
                order.deliveryDate.day,
              );

              // ✅ Nếu đã qua ngày giao → TRỄ
              if (today.isAfter(deliveryDay)) {
                isLate = true;
              }
            }

            // ✅ TH3: Có công đoạn trễ (chưa thiết lập thời gian nhưng đã quá ngày giao)
            if (!isLate && order.stages.isNotEmpty) {
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);

              // Kiểm tra xem có công đoạn nào chưa xong mà đã quá hạn không
              for (var stage in order.stages) {
                if (stage.status != 'done' && stage.plannedEnd != null) {
                  final deadline = DateTime(
                    stage.plannedEnd!.year,
                    stage.plannedEnd!.month,
                    stage.plannedEnd!.day,
                  );

                  if (today.isAfter(deadline)) {
                    isLate = true;
                    break;
                  }
                }
              }
            }

            // ✅ Priority:
            // 1 = Trễ (đỏ)
            // 2 = Đang sản xuất (xanh/cam)
            // 3 = Hoàn thành (xanh lá)
            if (isLate) return 1;

            if (order.overallStatus == 'in_progress' ||
                (order.status != 'completed' &&
                    order.overallStatus != 'done' &&
                    order.overallStatus != 'completed_early' &&
                    order.overallStatus != 'completed_late')) {
              return 2;
            }

            if (order.status == 'completed' ||
                order.overallStatus == 'done' ||
                order.overallStatus == 'completed_early' ||
                order.overallStatus == 'completed_late') {
              return 3;
            }

            return 4;
          }

          final priA = getPriority(a);
          final priB = getPriority(b);

          if (priA != priB) return priA.compareTo(priB);

          final remA = parseRemainingDays(a.remainingDays);
          final remB = parseRemainingDays(b.remainingDays);

          return remA.compareTo(remB);
        });



        // ✅ Nếu là trang đầu tiên, thay thế danh sách
        // Nếu là trang tiếp theo, thêm vào danh sách hiện tại
        if (page == 1) {
          orders = filtered;
        } else {
          orders.addAll(filtered);
        }

        // Phân loại
        doorOrders = orders.where((o) => o.orderType == "door").toList();
        metalOrders = orders.where((o) => o.orderType == "metal").toList();






        loading = false;
        isLoadingMore = false;
      });

      // ✅ Cập nhật hasMoreData
      if (meta != null) {
        currentPage = meta['current_page'] ?? page;
        totalPages = meta['last_page'] ?? 1;
        hasMoreData = currentPage < totalPages;


      } else {
        // Không có pagination → hasMoreData = false
        hasMoreData = false;

      }

    } on DioException catch (e) {

      setState(() {
        loading = false;
        isLoadingMore = false;
      });
      if (e.response?.statusCode == 401) {
        await AuthService.handle401();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải đơn hàng: ${e.message}')),
      );
    } catch (e) {
      setState(() {
        loading = false;
        isLoadingMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi không xác định: $e')),
      );
    }
  }

  Future<void> fetchUser() async {
    try {
      final u = await AuthService.me();
      setState(() => user = u);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await AuthService.handle401();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi tải thông tin user: ${e.message}")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi không xác định: $e")),
      );
    }
  }
  String _formatCommentTime(String? dateStr) {
    if (dateStr == null) return '';

    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) {
        return 'Vừa xong';
      } else if (diff.inMinutes < 60) {
        return '${diff.inMinutes} phút trước';
      } else if (diff.inHours < 24) {
        return '${diff.inHours} giờ trước';
      } else if (diff.inDays < 7) {
        return '${diff.inDays} ngày trước';
      } else {
        return DateFormat('dd/MM HH:mm').format(date);
      }
    } catch (e) {
      return '';
    }
  }
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Xác nhận đăng xuất"),
        content: const Text("Bạn có chắc muốn đăng xuất không?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Hủy")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Đăng xuất")),
        ],
      ),
    );

    if (confirm != true) return;

    await AuthService.logout(); // Gọi API logout
    await AuthService.clearUserCache(); // Xóa cache local

    navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
  }

  Color getStatusColor(String status) {
    switch (status) {
      case "completed":
        return Colors.green;
      case "late":
        return Colors.red;
      case "in_progress":
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
  String translateStatus(String status) {
    switch (status) {
      case 'pending':
        return 'Chờ xử lý';

      case 'in_progress':
        return 'Đang sản xuất';

      case 'late':
        return 'Trễ hạn';

      case 'completed':
      case 'done':
        return 'Hoàn thành';

      case 'completed_early':
        return 'Hoàn thành sớm';

      case 'completed_late':
        return 'Hoàn thành trễ';

      default:
        return status;
    }
  }
  /// 📊 Hàm chọn tháng và xuất file thống kê Excel
  Future<void> _exportStatistics(BuildContext context, int monthCount) async {
    final selectedMonth = await showMonthYearPicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('vi'),
    );

    if (selectedMonth == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "📦 Đang xuất file Excel thống kê từ ${DateFormat('MM/yyyy').format(selectedMonth)} (${monthCount} tháng)...",
        ),
        duration: const Duration(seconds: 3),
      ),
    );

    await OrderService.exportMonthlyStatisticsExcel(
      context,
      monthCount,
      selectedMonth,
    );

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }
  Future<void> _exportCustomMonths(BuildContext context) async {
    final now = DateTime.now();
    final List<String> selectedMonths = [];
    final months = List.generate(12, (i) => i + 1);
    final year = now.year;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                width: 400,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE60012),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      child: Text(
                        "Chọn các tháng muốn xuất",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: months.map((m) {
                            final val = "$year-${m.toString().padLeft(2, '0')}";
                            final isSelected = selectedMonths.contains(val);
                            return ChoiceChip(
                              label: Text("Thg $m"),
                              selected: isSelected,
                              selectedColor: const Color(0xFFE60012),
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : Colors.black,
                                fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              onSelected: (v) {
                                setState(() {
                                  if (v) {
                                    selectedMonths.add(val);
                                  } else {
                                    selectedMonths.remove(val);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("Hủy"),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE60012),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => Navigator.pop(ctx, selectedMonths),
                          child: const Text("OK", style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((result) async {
      if (result == null || result.isEmpty) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("📦 Đang xuất thống kê cho ${result.length} tháng...")),
      );
      await OrderService.exportCustomMonthsExcel(context, result);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    });
  }
  // 🔹 Widget hiển thị từng card đơn hàng
  Widget buildOrderCard(Order o) {
    // 🔹 Hàm lấy số ngày âm từ remainingDays (để biết trễ bao lâu)
    int getLateDays(String? text) {
      if (text == null) return 0;
      final regex = RegExp(r'-\s*(\d+)\s*ngày');
      final match = regex.firstMatch(text);
      if (match != null) {
        return int.tryParse(match.group(1) ?? '0') ?? 0;
      }
      return 0;
    }

    // ✅ THÊM LOGIC KIỂM TRA TRỄ CHO ĐƠN CHƯA CÓ CÔNG ĐOẠN
    bool isOverdue = false;

    // TH1: overallStatus báo trễ
    // if (o.overallStatus == "late") {
    //   isOverdue = true;
    // }

    // TH2: Đơn chưa hoàn thành + đã quá ngày giao
    if (o.status != 'completed' &&
        o.overallStatus != 'done' &&
        o.overallStatus != 'completed_early' &&
        o.overallStatus != 'completed_late') {

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // ✅ TH1: Kiểm tra ngày giao
      final deliveryDay = DateTime(
        o.deliveryDate.year,
        o.deliveryDate.month,
        o.deliveryDate.day,
      );

      if (today.isAfter(deliveryDay)) {
        isOverdue = true;
      }

      // ✅ TH2: Kiểm tra công đoạn trễ
      if (!isOverdue && o.stages.isNotEmpty) {
        for (var stage in o.stages) {
          if (stage.status != 'done' && stage.plannedEnd != null) {
            final deadline = DateTime(
              stage.plannedEnd!.year,
              stage.plannedEnd!.month,
              stage.plannedEnd!.day,
            );

            if (today.isAfter(deadline)) {
              isOverdue = true;
              break;
            }
          }
        }
      }
    }

    // ✅ KIỂM TRA GIA HẠN
    bool isExtended = false;
    if (o.originalDeliveryDate != null) {
      final originalDay = DateTime(
        o.originalDeliveryDate!.year,
        o.originalDeliveryDate!.month,
        o.originalDeliveryDate!.day,
      );
      final currentDay = DateTime(
        o.deliveryDate.year,
        o.deliveryDate.month,
        o.deliveryDate.day,
      );

      if (currentDay.isAfter(originalDay)) {
        isExtended = true;
      }
    }

    // ✅ QUYẾT ĐỊNH MÀU SẮC
    Color borderColor;
    Color bgColor;
    double borderWidth;

    final lateDays = getLateDays(o.remainingDays);
    final isSeverelyLate = isOverdue && lateDays > 3;

    if (isOverdue) {
      // 🔴 TRỄ HẠN (kể cả đã gia hạn) → ĐỎ
      borderColor = isSeverelyLate ? Colors.red.shade800 : Colors.red;
      bgColor = isSeverelyLate ? Colors.red.shade100 : Colors.red.shade50;
      borderWidth = isSeverelyLate ? 3 : 2;
    } else if (isExtended) {
      // 🟠 ĐÃ GIA HẠN + ĐANG ĐÚNG HẠN → CAM
      borderColor = Colors.orange.shade600;
      bgColor = Colors.orange.shade50;
      borderWidth = 2;
    } else {
      // ⚪ BÌNH THƯỜNG → TRẮNG
      borderColor = const Color(0xFFE0E0E0);
      bgColor = Colors.white;
      borderWidth = 1;
    }

    // 🔹 Tìm công đoạn trễ (nếu có)
    String? lateStageName;
    try {
      if (o.stages.isNotEmpty) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day); // ✅ Chỉ lấy ngày

        final lateStages = o.stages.where((s) {
          // ✅ CHỈ TÍNH TRỄ NẾU:
          // 1. Công đoạn chưa hoàn thành
          // 2. planned_end (HIỆN TẠI) đã quá hạn (so sánh theo NGÀY)
          if (s.status == 'done' || s.status == 'completed') {
            return false;
          }

          if (s.plannedEnd != null) {
            final deadline = DateTime(
              s.plannedEnd!.year,
              s.plannedEnd!.month,
              s.plannedEnd!.day,
            );

            // ✅ Chỉ báo trễ khi ĐÃ QUA ngày deadline
            return today.isAfter(deadline);
          }

          return false;
        }).toList();

        if (lateStages.isNotEmpty) {
          lateStageName = lateStages.map((s) => s.name).join(', ');
        }
      }
    } catch (e) {
      lateStageName = null;
    }

    return Stack(
      children: [
        Card(
          elevation: 4,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: borderColor,
              width: isOverdue ? (isSeverelyLate ? 3 : 2) : 1,
            ),
          ),
          color: bgColor,

          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "${o.projectName} (${o.orderNo})",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: getStatusColor(o.overallStatus),
                  ),
                ),
                // ✅ HIỂN THỊ BANNER HOÃN NẾU ĐƠN HÀNG BỊ HOÃN
                if (o.isPaused)
                  Container(
                    margin: const EdgeInsets.only(top: 4, bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.pause_circle, color: Colors.orange, size: 16),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            "🛑 Đơn hàng đang hoãn${o.pauseReason != null ? ': ${o.pauseReason}' : ''}",
                            style: const TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 4),
                Text(
                  "Trạng thái: ${translateStatus(
                      o.status == "completed" ? "completed" : o.overallStatus
                  )}",
                  style: const TextStyle(color: GoonamTheme.secondary),
                ),

                if (lateStageName != null)
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          "Công đoạn trễ: $lateStageName",
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                if (o.companyName != null && o.companyName!.isNotEmpty)
                  Text("Công ty: ${o.companyName}"),
                Text("Số lượng: ${o.quantity}"),
                Text("Mô tả: ${o.description}"),
                Text("Ngày đặt: ${DateFormat('dd/MM/yyyy').format(o.orderDate)}"),

                // ✅ HIỂN THỊ NGÀY GIAO + NGÀY GIAO GÓC TRÊN CÙNG 1 DÒNG
                // ✅ HIỂN THỊ NGÀY GIAO + NGÀY GIAO GÓC TRÊN CÙNG 1 DÒNG
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 14, color: Colors.black),
                    children: [
                      const TextSpan(text: "Ngày giao: "),
                      TextSpan(
                        text: DateFormat('dd/MM/yyyy').format(o.deliveryDate),

                      ),
                      if (o.originalDeliveryDate != null &&
                          o.originalDeliveryDate!.isBefore(o.deliveryDate))
                        TextSpan(
                          text: " (Ngày giao gốc: ${DateFormat('dd/MM/yyyy').format(o.originalDeliveryDate!)})",
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
                // ✅ THÊM ĐOẠN NÀY - Hiển thị comment mới nhất
                if (o.latestComment != null)
                  InkWell(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrderDetailPage(
                            orderId: o.id,
                            initialTab: "comments",
                          ),
                        ),
                      );

                      if (mounted) {
                        await fetchOrders(search: _searchController.text);
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(top: 6, bottom: 4),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: o.unreadCommentsCount > 0 // ✅ ĐỔI ĐIỀU KIỆN
                            ? Colors.blue.shade100
                            : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: o.unreadCommentsCount > 0 // ✅ ĐỔI ĐIỀU KIỆN
                              ? Colors.blue.shade400
                              : Colors.blue.shade200,
                          width: o.unreadCommentsCount > 0 ? 2 : 1, // ✅ ĐỔI ĐIỀU KIỆN
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.comment, color: Colors.blue, size: 14),
                              const SizedBox(width: 4),
                              // ✅ HIỂN THỊ SỐ LƯỢNG COMMENT CHƯA ĐỌC
                              if (o.unreadCommentsCount > 0)
                                Container(
                                  margin: const EdgeInsets.only(right: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${o.unreadCommentsCount}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              Text(
                                o.latestComment!['user_name'] ?? 'Unknown',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: o.unreadCommentsCount > 0 // ✅ ĐỔI ĐIỀU KIỆN
                                      ? Colors.blue.shade800
                                      : Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "• ${_formatCommentTime(o.latestComment!['created_at'])}",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            o.latestComment!['body'] ?? '',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                              fontWeight: o.unreadCommentsCount > 0 // ✅ ĐỔI ĐIỀU KIỆN
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                // ✅ THÊM ĐOẠN NÀY NGAY SAU "Ngày giao"
                Builder(
                  builder: (context) {
                    try {
                      final completedStages = o.stages
                          .where((s) => s.status == 'done' && s.actualEnd != null)
                          .toList()
                        ..sort((a, b) => b.actualEnd!.compareTo(a.actualEnd!));

                      if (completedStages.isEmpty) return const SizedBox.shrink();

                      final latest = completedStages.first;
                      return Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green, size: 16),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                "Hoàn thành gần nhất: ${latest.name} (${DateFormat('dd/MM/yyyy').format(latest.actualEnd!)})",
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    } catch (e) {
                      return const SizedBox.shrink();
                    }
                  },
                ),

                // 🔹 Hiển thị công đoạn hoàn thành gần nhất

                Row(
                  children: [
                    if (o.status == 'completed' ||
                        o.overallStatus == 'done' ||
                        o.overallStatus == 'completed_late' ||
                        o.overallStatus == 'completed_early')
                      Builder(
                        builder: (context) {
                          String label;
                          Color color;
                          IconData icon;

                          switch (o.overallStatus) {
                            case 'completed_late':
                              label = "⚠️ Hoàn thành trễ (so với kế hoạch gốc)";
                              color = Colors.red;
                              icon = Icons.warning_amber_rounded;
                              break;

                            case 'completed_early':
                              label = "✅ Hoàn thành sớm (trước hạn)";
                              color = Colors.blue;
                              icon = Icons.rocket_launch;
                              break;

                            case 'done':
                            case 'completed':
                              label = "✅ Hoàn thành đúng hạn";
                              color = Colors.green;
                              icon = Icons.check_circle;
                              break;

                            default:
                              if (o.actualEnd != null && o.deliveryDate != null) {
                                if (o.actualEnd!.isBefore(o.deliveryDate!)) {
                                  label = "✅ Hoàn thành sớm (trước hạn)";
                                  color = Colors.blue;
                                  icon = Icons.rocket_launch;
                                } else if (o.actualEnd!.isBefore(
                                  o.deliveryDate!.add(const Duration(hours: 23, minutes: 59)),
                                )) {
                                  label = "✅ Hoàn thành đúng hạn";
                                  color = Colors.green;
                                  icon = Icons.check_circle;
                                } else {
                                  label = "⚠️ Hoàn thành trễ (so với kế hoạch gốc)";
                                  color = Colors.red;
                                  icon = Icons.warning_amber_rounded;
                                }
                              } else {
                                label = "⚙️ Hoàn thành";
                                color = Colors.grey;
                                icon = Icons.check_circle_outline;
                              }
                          }

                          return Row(
                            children: [
                              Icon(icon, color: color, size: 18),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: color),
                                ),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      )
                    else
                      Row(
                        children: [
                          Icon(
                            (o.remainingDays?.startsWith('-') ?? false)
                                ? Icons.warning_amber_rounded
                                : Icons.access_time,
                            color: (o.remainingDays?.startsWith('-') ?? false)
                                ? Colors.red.shade700
                                : (o.remainingDays?.contains('0 ngày') ?? false)
                                ? Colors.orange.shade700
                                : Colors.green.shade700,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (o.remainingDays?.startsWith('-') ?? false)
                                  ? Colors.red.shade50
                                  : (o.remainingDays?.contains('0 ngày') ?? false)
                                  ? Colors.orange.shade50
                                  : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: (o.remainingDays?.startsWith('-') ?? false)
                                    ? Colors.red.shade300
                                    : (o.remainingDays?.contains('0 ngày') ?? false)
                                    ? Colors.orange.shade300
                                    : Colors.green.shade300,
                              ),
                            ),
                            child: Text(
                              "Còn lại: ${o.remainingDays ?? '-'}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: (o.remainingDays?.startsWith('-') ?? false)
                                    ? Colors.red.shade700
                                    : (o.remainingDays?.contains('0 ngày') ?? false)
                                    ? Colors.orange.shade700
                                    : Colors.green.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),

                const SizedBox(height: 8),

                Align(
                  alignment: Alignment.bottomRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility, color: Colors.blue),
                        tooltip: "Xem chi tiết",
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => OrderDetailPage(orderId: o.id)),
                          );

                          // ✅ Đợi 1 frame để đảm bảo widget đã mounted
                          Future.microtask(() async {
                            if (mounted) {
                              await fetchOrders(search: _searchController.text);
                            }
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.orange),
                        tooltip: "Chỉnh sửa",
                        onPressed: () async {
                          final updated = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => OrderFormPage(order: o)),
                          );
                          if (updated != null) await fetchOrders(search: _searchController.text);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: "Xóa",
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text("Xóa đơn hàng"),
                              content: const Text("Bạn có chắc muốn xóa đơn hàng này?"),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Hủy")),
                                ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Xóa")),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await OrderService.deleteOrder(context, o.id);
                            await fetchOrders(search: _searchController.text, silent: true); // ✅ THÊM silent: true
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ✅ THÊM ICON HOÃN Ở GÓC TRÊN PHẢI (ƯU TIÊN CAO HƠN ICON TRỄ)
        if (o.isPaused)
          const Positioned(
            top: 8,
            right: 8,
            child: Icon(Icons.pause_circle, color: Colors.orange, size: 24),
          )
        else if (isSeverelyLate)
          const Positioned(
            top: 8,
            right: 8,
            child: Icon(Icons.alarm, color: Colors.red, size: 24),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        shadowColor: Colors.black12,
        titleSpacing: 0,
        title: Row(
          children: [
            Image.asset(
              'assets/logo_icon.png',
              width: 28,
            ),
            const SizedBox(width: 8),
            const Text(
              "Đơn hàng",
              style: TextStyle(
                color: GoonamTheme.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Tìm đơn hàng...",
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (value) => fetchOrders(search: value),
              ),
            ),
          ],
        ),
        actions: [
          ValueListenableBuilder<int>(
            valueListenable: GlobalBadge.unreadComments,
            builder: (_, count, __) {
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.comment, color: GoonamTheme.secondary),
                    tooltip: "Bình luận mới",
                    onPressed: () => showUnreadCommentsModal(context),
                  ),
                  if (count > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          count.toString(),
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),



          DropdownButton<String>(
            value: _filterStatus,
            underline: const SizedBox(),
            icon: const Icon(Icons.filter_list, color: GoonamTheme.secondary),
            onChanged: (value) {
              setState(() {
                _filterStatus = value!;
                fetchOrders(search: _searchController.text);
              });
            },
            items: [
              DropdownMenuItem(value: "all", child: Text("Tất cả ($countAll)")),
              DropdownMenuItem(value: "in_progress", child: Text("Đang sản xuất ($countInProgress)")),
              DropdownMenuItem(value: "late", child: Text("Trễ ($countLate)")),
              // DropdownMenuItem(value: "completed", child: Text("Hoàn thành ($countCompleted)")),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.download, color: GoonamTheme.secondary),
            tooltip: "Xuất thống kê",
            onSelected: (value) async {
              if (value == "export_custom") {
                await _exportCustomMonths(context);
              } else if (value == "export_1m") {
                await _exportStatistics(context, 1);
              } else if (value == "export_3m") {
                await _exportStatistics(context, 3);
              }else if (value == "export_daily") {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2023),
                  lastDate: DateTime(2030),
                  locale: const Locale('vi'),
                );
                if (picked != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("📦 Đang xuất kế hoạch ngày...")),
                  );
                  await StageService.exportDailyPlan(context, picked);
                }
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: "export_1m", child: Text("📊 Xuất thống kê 1 tháng")),
              PopupMenuItem(value: "export_3m", child: Text("📊 Xuất thống kê 3 tháng liền kề")),
              PopupMenuItem(value: "export_custom", child: Text("📊 Xuất thống kê tùy chọn tháng")),
              PopupMenuItem(value: "export_daily", child: Text("📄 Xuất kế hoạch ngày (Excel)")),

            ],
          ),
        ],
      ),
      drawer: ClipRRect(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        child: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFE60012), Color(0xFFB5000F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              currentAccountPicture: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.asset('assets/logo_icon.png'),
              ),
              accountName: Text(
                user?['name'] ?? "Người dùng",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              accountEmail: Text(
                user?['email'] ?? "",
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            if (user?['role'] == 'admin' || user?['role'] == 'director') // ✅ chỉ hiện với admin/director
              ListTile(
                leading: const Icon(Icons.person_add),
                title: const Text("Tạo người dùng mới"),
                onTap: () {
                  Navigator.pushNamed(context, '/createUser');
                },
              ),
            ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: const Text("Đơn hàng hoàn thành"),
              onTap: () async {
                Navigator.pop(context); // Đóng Drawer



                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CompletedOrdersPage()),
                );



                // ✅ LUÔN refresh khi quay lại
                if (mounted) {
                  await fetchOrders(search: _searchController.text);
                }
              },
            ),
            // ✅ Chỉ hiện với admin/director/manager
            if (user?['role'] == 'admin' ||
                user?['role'] == 'director' ||
                user?['role'] == 'manager')
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text("Thùng rác"),
                onTap: () async {
                  Navigator.pop(context); // Đóng Drawer

                  final needReload = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TrashPage()),
                  );

                  if (needReload == true) {
                    await fetchOrders(search: _searchController.text);
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Đăng xuất"),
              onTap: _logout,
            ),
          ],
        ),
      ),
      ),
      body: Stack(
        children: [
          // ✅ Nội dung chính
          RefreshIndicator(
            onRefresh: () => fetchOrders(search: _searchController.text),
            child: Row(
              children: [
                // 🔹 Cột trái: Đơn hàng CỬA
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        color: Colors.blue.shade100,
                        child: Text(
                          "🚪 Đơn hàng CỬA (${doorOrders.length})",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.only(left: 8, right: 8, top: 4, bottom: 80),
                          itemCount: doorOrders.length + (hasMoreData ? 1 : 0), // ✅ +1 nếu còn data
                          itemBuilder: (context, index) {
                            // ✅ Nếu là item cuối cùng và còn data → hiện nút Load More
                            if (index == doorOrders.length && hasMoreData) {
                              return Padding(
                                padding: const EdgeInsets.all(16),
                                child: Center(
                                  child: isLoadingMore
                                      ? const CircularProgressIndicator()
                                      : ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                    ),
                                    icon: const Icon(Icons.arrow_downward),
                                    label: const Text("Tải thêm đơn Cửa"),
                                    onPressed: () {
                                      currentPage++;
                                      fetchOrders(
                                        search: _searchController.text,
                                        page: currentPage,
                                      );
                                    },
                                  ),
                                ),
                              );
                            }

                            return buildOrderCard(doorOrders[index]);
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const VerticalDivider(width: 1, thickness: 1, color: Colors.grey),

                // 🔹 Cột phải: Đơn hàng KIM LOẠI
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        color: Colors.orange.shade100,
                        child: Text(
                          "🔩 Đơn hàng KIM LOẠI (${metalOrders.length})",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.only(left: 8, right: 8, top: 4, bottom: 80),
                          itemCount: metalOrders.length + (hasMoreData ? 1 : 0), // ✅ +1 nếu còn data
                          itemBuilder: (context, index) {
                            // ✅ Nếu là item cuối cùng và còn data → hiện nút Load More
                            if (index == metalOrders.length && hasMoreData) {
                              return Padding(
                                padding: const EdgeInsets.all(16),
                                child: Center(
                                  child: isLoadingMore
                                      ? const CircularProgressIndicator()
                                      : ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                    ),
                                    icon: const Icon(Icons.arrow_downward),
                                    label: const Text("Tải thêm đơn Kim loại"),
                                    onPressed: () {
                                      currentPage++;
                                      fetchOrders(
                                        search: _searchController.text,
                                        page: currentPage,
                                      );
                                    },
                                  ),
                                ),
                              );
                            }

                            return buildOrderCard(metalOrders[index]);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ✅ PANEL DEBUG (nổi lên trên)

        ],
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: GoonamTheme.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const OrderFormPage()),
          );

          // ✅ Nếu trả về true → reload danh sách
          if (result == true || result != null) {
            fetchOrders(search: _searchController.text);
          }
        },
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
  @override
  void dispose() {
    _commentTimer?.cancel(); // 🔹 Hủy Timer khi thoát trang
    _searchController.dispose(); // 🔹 Giải phóng bộ nhớ của TextEditingController
    super.dispose();
  }
}
