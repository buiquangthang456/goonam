import 'package:flutter/material.dart';
import 'package:goonam_manage_app/models/order.dart';
import 'package:goonam_manage_app/services/order_service.dart';
import 'package:goonam_manage_app/services/auth_service.dart';
import 'package:goonam_manage_app/pages/order_detail_page.dart';
import 'package:intl/intl.dart';

class CompletedOrdersPage extends StatefulWidget {
  const CompletedOrdersPage({super.key});

  @override
  State<CompletedOrdersPage> createState() => _CompletedOrdersPageState();
}

class _CompletedOrdersPageState extends State<CompletedOrdersPage> {
  List<Order> orders = [];
  bool loading = true;
  String? userRole; // ✅ THÊM BIẾN LƯU ROLE
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserRole(); // ✅ LẤY ROLE
    fetchCompletedOrders();
  }

  // ✅ LẤY ROLE NGƯỜI DÙNG
  Future<void> _loadUserRole() async {
    final role = await AuthService.getRole();
    setState(() {
      userRole = role;
    });
  }

  Future<void> fetchCompletedOrders({String? search}) async {
    try {
      setState(() => loading = true);

      final response = await OrderService.getCompletedOrders(search: search);

      setState(() {
        orders = response;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải đơn hàng: $e')),
        );
      }
    }
  }

  // ✅ XÓA 1 ĐƠN HÀNG
  Future<void> _deleteOrder(Order order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa đơn hàng "${order.projectName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final success = await OrderService.deleteCompletedOrder(context, order.id);
      if (success) {
        fetchCompletedOrders(search: _searchController.text);
      }
    }
  }

  // ✅ XÓA TẤT CẢ
  Future<void> _deleteAllOrders() async {
    if (orders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có đơn hàng nào để xóa')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Xác nhận xóa tất cả'),
        content: Text('Bạn có chắc muốn xóa ${orders.length} đơn hàng hoàn thành?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa tất cả', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final success = await OrderService.deleteAllCompletedOrders(context);
      if (success) {
        fetchCompletedOrders(search: _searchController.text);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // ✅ CHỈ ADMIN MỚI THẤY NÚT XÓA
    final isAdmin = userRole == 'admin';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        shadowColor: Colors.black12,
        titleSpacing: 0,
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 8),
            const Text(
              "Đơn hàng hoàn thành",
              style: TextStyle(
                color: Color(0xFFE60012),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "${orders.length}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
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
                onSubmitted: (value) => fetchCompletedOrders(search: value),
              ),

            ),
          ],
        ),
        actions: [
          // ✅ NÚT XÓA TẤT CẢ (CHỈ ADMIN)
          if (isAdmin && orders.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.red),
              tooltip: 'Xóa tất cả',
              onPressed: _deleteAllOrders,
            ),
        ],
      ),
      body: Column(
        children: [
          // ✅ BANNER CẢNH BÁO
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.orange.shade300, width: 1),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "⚠️ Các đơn hoàn thành sẽ tự động xóa vĩnh viễn sau 2 năm",
                    style: TextStyle(
                      color: Colors.orange.shade900,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ✅ DANH SÁCH ĐƠN HÀNG
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => fetchCompletedOrders(search: _searchController.text),
              child: orders.isEmpty
                  ? const Center(child: Text("Không có đơn hàng hoàn thành"))
                  : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final o = orders[index];
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: const Icon(Icons.check_circle, color: Colors.green, size: 32),
                      title: Text(
                        "${o.projectName} (${o.orderNo})",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Công ty: ${o.companyName ?? '-'}"),
                          Text(
                            o.completedAt != null
                                ? "✅ Hoàn thành: ${DateFormat('dd/MM/yyyy HH:mm').format(o.completedAt!)}"
                                : o.actualEnd != null
                                ? "Hoàn thành: ${DateFormat('dd/MM/yyyy').format(o.actualEnd!)}"
                                : "Hoàn thành: Chưa có thông tin",
                            style: TextStyle(
                              color: o.completedAt != null || o.actualEnd != null
                                  ? Colors.green
                                  : Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility, color: Colors.blue),
                            tooltip: "Xem chi tiết",
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => OrderDetailPage(orderId: o.id),
                                ),
                              );

                              if (mounted) {
                                await fetchCompletedOrders(search: _searchController.text);
                              }
                            },
                          ),
                          if (isAdmin)
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: "Xóa",
                              onPressed: () => _deleteOrder(o),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}