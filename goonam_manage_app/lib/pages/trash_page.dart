import 'package:flutter/material.dart';
import '../models/order.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import 'package:intl/intl.dart';

class TrashPage extends StatefulWidget {
  const TrashPage({super.key});

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  List<Order> trashedOrders = [];
  List<Order> filteredOrders = [];
  bool loading = true;
  bool hasRestored = false;
  String? userRole;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchTrash();
    fetchUserRole();
  }

  Future<void> fetchUserRole() async {
    final u = await AuthService.getStoredUser();
    setState(() {
      userRole = u?['role'];
    });
  }

  // ✅ THÊM THAM SỐ silent
  Future<void> fetchTrash({bool silent = false}) async {
    // ✅ Chỉ hiển thị loading nếu KHÔNG phải silent refresh
    if (!silent) {
      setState(() => loading = true);
    }

    try {
      final list = await OrderService.getTrash();
      setState(() {
        trashedOrders = list;
        filteredOrders = list;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi tải thùng rác: $e")),
      );
    }
  }

  void _filterOrders(String query) {
    if (query.isEmpty) {
      setState(() {
        filteredOrders = trashedOrders;
      });
      return;
    }

    final lowerQuery = query.toLowerCase();
    setState(() {
      filteredOrders = trashedOrders.where((order) {
        return order.orderNo.toLowerCase().contains(lowerQuery) ||
            order.projectName.toLowerCase().contains(lowerQuery) ||
            (order.companyName?.toLowerCase().contains(lowerQuery) ?? false) ||
            (order.description?.toLowerCase().contains(lowerQuery) ?? false);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    // ✅ CHỈ hiển thị loading khi CHƯA có dữ liệu
    if (loading && trashedOrders.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final canModify = userRole == 'admin' ||
        userRole == 'director' ||
        userRole == 'manager';

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, hasRestored);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("🗑️ Thùng rác"),
          backgroundColor: Colors.red.shade700,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context, hasRestored);
            },
          ),
          actions: [
            if (canModify && filteredOrders.isNotEmpty)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) async {
                  if (value == 'empty_trash') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("⚠️ Xóa tất cả"),
                        content: Text(
                          "Bạn có chắc muốn XÓA VĨNH VIỄN ${filteredOrders.length} đơn hàng?\n\nHành động này KHÔNG THỂ KHÔI PHỤC!",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text("Hủy"),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text("Xóa tất cả"),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      final success = await OrderService.emptyTrash(context);
                      if (success) {
                        await fetchTrash(silent: true); // ✅ THÊM silent: true
                      }
                    }
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'empty_trash',
                    child: Row(
                      children: [
                        Icon(Icons.delete_sweep, color: Colors.red),
                        SizedBox(width: 8),
                        Text("Xóa tất cả", style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Tìm kiếm theo mã đơn, dự án, công ty...",
                  hintStyle: const TextStyle(color: Colors.white70),
                  prefixIcon: const Icon(Icons.search, color: Colors.white),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white),
                    onPressed: () {
                      _searchController.clear();
                      _filterOrders('');
                    },
                  )
                      : null,
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: _filterOrders,
              ),
            ),
          ),
        ),

        body: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.orange.shade100,
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "⏰ Các mục trong thùng rác sẽ tự động bị xóa vĩnh viễn sau 1 năm",
                      style: TextStyle(color: Colors.black87, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: filteredOrders.isEmpty
                  ? Center(
                child: Text(
                  _searchController.text.isEmpty
                      ? "Thùng rác trống"
                      : "Không tìm thấy kết quả",
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: filteredOrders.length,
                itemBuilder: (context, index) {
                  final o = filteredOrders[index];
                  return Card(
                    color: Colors.red.shade50,
                    child: ListTile(
                      leading: const Icon(Icons.delete_outline, color: Colors.red),
                      title: Text("${o.projectName} (${o.orderNo})"),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Công ty: ${o.companyName ?? '-'}"),
                          Text("Ngày đặt: ${DateFormat('dd/MM/yyyy').format(o.orderDate)}"),
                          if (o.deletedAt != null)
                            Text(
                              "Xóa lúc: ${DateFormat('dd/MM/yyyy HH:mm').format(o.deletedAt!)}",
                              style: const TextStyle(color: Colors.red, fontSize: 12),
                            ),
                        ],
                      ),
                      trailing: canModify
                          ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.restore, color: Colors.green),
                            tooltip: "Khôi phục",
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text("Khôi phục đơn hàng"),
                                  content: const Text("Bạn có chắc muốn khôi phục đơn hàng này?"),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text("Hủy"),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text("Khôi phục"),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                final restored = await OrderService.restoreOrder(context, o.id);
                                if (restored != null) {
                                  setState(() {
                                    hasRestored = true;
                                  });
                                  await fetchTrash(silent: true); // ✅ THÊM silent: true
                                }
                              }
                            },
                          ),

                          IconButton(
                            icon: const Icon(Icons.delete_forever, color: Colors.red),
                            tooltip: "Xóa vĩnh viễn",
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text("⚠️ Xóa vĩnh viễn"),
                                  content: const Text(
                                    "Hành động này KHÔNG THỂ KHÔI PHỤC!\nBạn có chắc chắn?",
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text("Hủy"),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                      ),
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text("Xóa vĩnh viễn"),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                await OrderService.forceDeleteOrder(context, o.id);
                                await fetchTrash(silent: true); // ✅ THÊM silent: true
                              }
                            },
                          ),
                        ],
                      )
                          : null,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}