import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:goonam_manage_app/pages/stage_service.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import '../models/order.dart';
import 'package:intl/intl.dart';

class OrderFormPage extends StatefulWidget {
  final Order? order;


  const OrderFormPage({super.key, this.order});

  @override
  State<OrderFormPage> createState() => _OrderFormPageState();

}

class _OrderFormPageState extends State<OrderFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _projectNameController = TextEditingController();
  final _orderNoController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController();
  final _companyController = TextEditingController();


  DateTime? _orderDate;
  DateTime? _deliveryDate;
  String _orderType = "door";
  String _status = "in_progress";
  List<Map<String, dynamic>> _stages = [];
  bool _loadingStages = false;
  bool _isSubmitting = false;
  String? _adminNote;
  @override
  void initState() {
    super.initState();

    if (widget.order != null) {
      // Nếu đang chỉnh sửa
      final o = widget.order!;
      _projectNameController.text = o.projectName;
      _orderNoController.text = o.orderNo;
      _descriptionController.text = o.description ?? "";
      _quantityController.text = o.quantity.toString();
      _orderDate = o.orderDate;
      _deliveryDate = o.deliveryDate;
      _orderType = o.orderType;
      _status = o.status;
      _companyController.text = o.companyName ?? "";

      // 🟢 THÊM ĐOẠN NÀY VÀO ĐÂY
      _stages = o.stages.map((s) {
        DateTime? parseDate(dynamic val) {
          if (val == null || val == "0") return null;
          if (val is DateTime) return val;
          if (val is String) {
            // ✅ Cố gắng parse chuỗi ISO hoặc yyyy-MM-dd
            try {
              return DateTime.parse(val);
            } catch (_) {
              return null;
            }
          }
          return null;
        }

        // ✅ Tính số ngày từ planned_start và planned_end
        final start = parseDate(s.plannedStart);
        final end = parseDate(s.plannedEnd);
        int days = 0;

        if (start != null && end != null) {
          days = end.difference(start).inDays + 1;
        }

        return {
          "id": s.id,
          "name": s.name,
          "sequence": s.sequence,
          "planned_start": start,
          "planned_end": end,
          "days": days, // ✅ THÊM DÒNG NÀY
        };
      }).toList();
    }
    else {
      // 🔥 Nếu đang tạo mới → load stage templates mặc định
      _loadStages();
    }
  }

  /// chọn ngày
  Future<void> _pickDate(BuildContext context, bool isOrderDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isOrderDate
          ? (_orderDate ?? DateTime.now())
          : (_deliveryDate ?? DateTime.now().add(const Duration(days: 7))),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isOrderDate) {
          _orderDate = picked;
        } else {
          _deliveryDate = picked;
        }
      });
    }
  }
  Future<void> _loadStages() async {
    setState(() => _loadingStages = true);

    try {
      final res = await Dio().get(
        "${AuthService.getBaseUrl()}/stage-templates",
        queryParameters: {"order_type": _orderType},
      );

      setState(() {
        _stages = List<Map<String, dynamic>>.from(res.data.map((t) => {
          "template_id": t["id"],
          "name": t["name"],
          "sequence": t["sequence"],
          "planned_start": safeParseDate(t["planned_start"]),
          "planned_end": safeParseDate(t["planned_end"]),
          "days": 0,
        }));
      });
    } catch (e) {
      debugPrint("Không tải được danh sách công đoạn: $e");
    } finally {
      setState(() => _loadingStages = false);
    }
  }


  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_orderDate == null || _deliveryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng chọn ngày đặt và ngày giao")),
      );
      return;
    }

    List<Map<String, dynamic>> stageDiffs = [];
    String? optionalNote;

    if (widget.order != null) {
      final oldStages = widget.order!.stages;

      for (int i = 0; i < _stages.length; i++) {
        final newS = _stages[i];
        final match = oldStages.firstWhereOrNull(
              (os) => os.id == newS['id'] || os.sequence == newS['sequence'],
        );

        if (match != null) {
          final oldStart = match.plannedStart;
          final oldEnd = match.plannedEnd;
          final newStart = newS['planned_start'];
          final newEnd = newS['planned_end'];

          // So sánh khác biệt
          final bool startChanged = (oldStart == null && newStart != null) ||
              (oldStart != null && newStart != null && !isSameDate(oldStart, newStart));
          final bool endChanged = (oldEnd == null && newEnd != null) ||
              (oldEnd != null && newEnd != null && !isSameDate(oldEnd, newEnd));

          if (startChanged || endChanged) {
            // Kiểm tra phạm vi
            if ((newStart != null && (newStart.isBefore(_orderDate!) || newStart.isAfter(_deliveryDate!))) ||
                (newEnd != null && (newEnd.isBefore(_orderDate!) || newEnd.isAfter(_deliveryDate!)))) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("❌ Ngày công đoạn phải nằm trong khoảng ngày đặt - ngày giao!")),
              );
              return;
            }

            // Ghi nhận thay đổi
            stageDiffs.add({
              'stage_id': match.id,
              'stage_name': newS['name'],
              'old_start': oldStart?.toIso8601String(),
              'old_end': oldEnd?.toIso8601String(),
              'new_start': newStart?.toIso8601String(),
              'new_end': newEnd?.toIso8601String(),
            });
          }
        }
      }

      // Nếu có thay đổi → hiện dialog xác nhận
      if (stageDiffs.isNotEmpty) {
        final noteCtrl = TextEditingController();
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: Text("Xác nhận thay đổi công đoạn (${stageDiffs.length})"),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Các thay đổi sẽ được ghi lại trong lịch sử:"),
                      const SizedBox(height: 8),
                      ...stageDiffs.map((d) {
                        String fmt(String? s) {
                          if (s == null || s.isEmpty) return '-';
                          final date = DateTime.tryParse(s);
                          if (date == null) return s.split('T').first;
                          return DateFormat('yyyy-MM-dd').format(date);
                        }

                        final oldS = fmt(d['old_start']);
                        final newS = fmt(d['new_start']);
                        final oldE = fmt(d['old_end']);
                        final newE = fmt(d['new_end']);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text("- ${d['stage_name']}: $oldS → $newS; $oldE → $newE"),
                        );
                      }),
                      const SizedBox(height: 12),
                      const Text("Ghi chú / lý do (tuỳ chọn):"),
                      const SizedBox(height: 4),
                      TextField(
                        controller: noteCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text("Hủy")),
                ElevatedButton(
                    onPressed: () {
                      _adminNote = noteCtrl.text.trim();
                      optionalNote = _adminNote;
                      Navigator.pop(ctx, true);
                    },
                    child: const Text("Xác nhận")),
              ],
            );
          },
        );

        // ❗ Dù người dùng không nhập lý do vẫn phải lưu history
        if (confirmed != true) return;
      }
    }

    setState(() => _isSubmitting = true);

    setState(() => _isSubmitting = true);

    try {
      final currentUser = await AuthService.me();
      final now = DateTime.now();

      final Map<String, dynamic> orderData = {
        "order_type": _orderType,
        "project_name": _projectNameController.text,
        "company_name": _companyController.text,
        "order_no": _orderNoController.text,
        "description": _descriptionController.text,
        "quantity": int.tryParse(_quantityController.text) ?? 0,
        "order_date": DateFormat('yyyy-MM-dd').format(_orderDate!),
        "delivery_date": DateFormat('yyyy-MM-dd').format(_deliveryDate!),
        "stages": _stages.map((s) => {
          if (s.containsKey('id')) 'id': s['id'],
          'template_id': s['template_id'],
          'name': s['name'],
          'sequence': s['sequence'],
          'planned_start': (s['planned_start'] == null)
              ? "0"
              : DateFormat('yyyy-MM-dd').format(s['planned_start']),
          'planned_end': (s['planned_end'] == null)
              ? "0"
              : DateFormat('yyyy-MM-dd').format(s['planned_end']),
          'material_request_date': (s['material_request_date'] == null)
              ? null
              : DateFormat('yyyy-MM-dd').format(s['material_request_date']),
        }).toList(),
      };

      // ✅ CHỈ GỬI status KHI TẠO MỚI
      if (widget.order == null) {
        orderData['status'] = 'in_progress';
      }

      // 🧩 Thêm admin note nếu có
      if (_adminNote != null && _adminNote!.trim().isNotEmpty) {
        orderData['admin_note'] = _adminNote!.trim();
      }

      // 🔹 Ghi history nếu có thay đổi công đoạn (khi cập nhật)
      if (widget.order != null && stageDiffs.isNotEmpty) {
        orderData['history'] = stageDiffs.map((d) => {
          "editor": currentUser?['name'] ?? 'Không rõ',
          "change": "Chỉnh thời gian công đoạn ${d['stage_name']}",
          "type": "stage_time_change",
          "change_mode": "admin_edit",
          "note": optionalNote ?? '',
          "date": now.toIso8601String(),
          "details": d,
        }).toList();
      }

      if (widget.order == null) {
        // ➕ THÊM MỚI
        await OrderService.createOrder(context, orderData);

        // ✅ LUÔN LUÔN QUAY LẠI VÀ RELOAD (không cần parse response)
        if (mounted) {
          Navigator.pop(context, true); // ← Trả về true để reload
        }
      } else {
        // 🛠️ CẬP NHẬT
        final updatedOrder = await OrderService.updateOrder(context, widget.order!.id, orderData);
        if (updatedOrder != null && mounted) Navigator.pop(context, updatedOrder);
      }
    } catch (e) {
      if (e is DioException) {
        OrderService.handleError(context, e);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi không xác định: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }

  }



  bool isSameDate(DateTime a, DateTime b) {
    return a.year==b.year && a.month==b.month && a.day==b.day;
  }

  DateTime? safeParseDate(dynamic val) {
    if (val == null || val == "0") return null;
    if (val is DateTime) return val;
    if (val is String) {
      try {
        return DateTime.parse(val);
      } catch (_) {
        return null;
      }
    }
    return null;
  }





  @override
  Widget build(BuildContext context) {
    final isEdit = widget.order != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? "Sửa đơn hàng" : "Thêm đơn hàng"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(15),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 12),
              TextFormField(
                controller: _projectNameController,
                decoration: const InputDecoration(labelText: "Tên dự án"),
                validator: (v) => v!.isEmpty ? "Nhập tên dự án" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _companyController,
                decoration: const InputDecoration(labelText: "Tên công ty"),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _orderNoController,
                decoration: const InputDecoration(labelText: "Mã đơn hàng"),
                validator: (v) => v!.isEmpty ? "Nhập mã đơn hàng" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(labelText: "Số lượng"),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? "Nhập số lượng" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: "Mô tả"),
              ),
              const SizedBox(height: 20),

              // dropdown order_type
              DropdownButtonFormField<String>(
                value: _orderType,
                decoration: const InputDecoration(labelText: "Loại đơn hàng"),
                items: const [
                  DropdownMenuItem(value: "door", child: Text("Cửa")),
                  DropdownMenuItem(value: "metal", child: Text("Kim loại")),
                ],
                onChanged: (v) async {
                  setState(() {
                    _orderType = v!;
                  });
                  await _loadStages();
                },
              ),
              const SizedBox(height: 20),

              // chọn ngày đặt
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "Ngày đặt: ${_orderDate != null ? DateFormat('dd/MM/yyyy').format(_orderDate!) : 'Chưa chọn'}",
                    ),
                  ),
                  TextButton(
                    onPressed: () => _pickDate(context, true),
                    child: const Text("Chọn ngày"),
                  ),
                ],
              ),

              // chọn ngày giao
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "Ngày giao: ${_deliveryDate != null ? DateFormat('dd/MM/yyyy').format(_deliveryDate!) : 'Chưa chọn'}",
                    ),
                  ),
                  TextButton(
                    onPressed: () => _pickDate(context, false),
                    child: const Text("Chọn ngày"),
                  ),
                ],
              ),

              const SizedBox(height: 30),
              if (_loadingStages)
                const Center(child: CircularProgressIndicator())
              else if (_stages.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    const Text(
                      "Công đoạn sản xuất",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    ..._stages.asMap().entries.map((entry) {
                      final i = entry.key;
                      final stage = entry.value;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(stage["name"], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              // 🔹 Ngày yêu cầu vật tư
                              // 🔹 Ngày yêu cầu vật tư (chỉ hiển thị ở công đoạn đầu tiên)
                              // if (i == 0) ...[
                              //   Row(
                              //     children: [
                              //       Expanded(
                              //         child: Text(
                              //           stage["material_request_date"] == null
                              //               ? "Ngày yêu cầu vật tư: Chưa chọn"
                              //               : "Yêu cầu vật tư: ${DateFormat('dd/MM/yyyy').format(safeParseDate(stage["material_request_date"])!)}",
                              //         ),
                              //       ),
                              //       TextButton(
                              //         onPressed: () async {
                              //           final picked = await showDatePicker(
                              //             context: context,
                              //             initialDate: stage["material_request_date"] ?? DateTime.now(),
                              //             firstDate: DateTime(2020),
                              //             lastDate: DateTime(2100),
                              //           );
                              //
                              //           if (picked == null) return;
                              //
                              //           setState(() {
                              //             stage["material_request_date"] = picked;
                              //           });
                              //
                              //           // 🔹 Chỉ gọi API nếu là sửa đơn hàng (đã có id)
                              //           if (widget.order != null && widget.order!.id != null && stage["id"] != null) {
                              //             try {
                              //               await StageService.updateMaterialRequestDate(
                              //                 context,
                              //                 widget.order!.id,
                              //                 stage["id"],
                              //                 picked,
                              //               );
                              //             } catch (e) {
                              //               debugPrint("Lỗi cập nhật vật tư: $e");
                              //             }
                              //           } else {
                              //             debugPrint("Tạo mới: chỉ lưu tạm ngày vật tư, chưa có orderId để cập nhật DB");
                              //           }
                              //         },
                              //
                              //         child: const Text("Chọn ngày", style: TextStyle(color: Colors.red)),
                              //       ),
                              //     ],
                              //   ),
                              //   const SizedBox(height: 8),
                              // ],
                              // const SizedBox(height: 8),

                              // 🗓️ Chọn ngày bắt đầu (chỉ cho phép ở công đoạn đầu tiên hoặc nếu chưa có auto start)
                              Row(
                                children: [
                                  Expanded(
                                    child: TextButton(
                                      onPressed: (i == 0)
                                          ? () async {
                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate: stage["planned_start"] ?? (_orderDate ?? DateTime.now()),
                                          firstDate: _orderDate ?? DateTime(2020),
                                          lastDate: _deliveryDate ?? DateTime(2100),
                                        );
                                        if (picked != null) {
                                          setState(() {
                                            stage["planned_start"] = picked;
                                            stage["planned_end"] = null;
                                          });
                                        }
                                      }
                                          : null,
                                      child: Text(
                                        stage["planned_start"] == null
                                            ? (i == 0 ? "Chọn ngày bắt đầu" : "Tự động sau công đoạn trước")
                                            : "Bắt đầu: ${DateFormat('dd/MM/yyyy').format(safeParseDate(stage["planned_start"])!)}",

                                      ),
                                    ),
                                  ),

                                  // ⏱️ Nhập số ngày (auto tính ngày kết thúc)
                                  Expanded(
                                    child: Builder(
                                      builder: (context) {
                                        final focusNode = FocusNode();

                                        final controller = TextEditingController(
                                          text: (stage["days"] ?? 0).toString(),
                                        );

                                        focusNode.addListener(() {
                                          if (!focusNode.hasFocus) {
                                            final days = int.tryParse(controller.text) ?? 0;

                                            // ⚠️ Nếu chưa có ngày bắt đầu mà nhập >0 ngày → cảnh báo
                                            // ✅ Nếu chưa có planned_start → tự tìm công đoạn trước có end để lấy ngày bắt đầu
                                            if (stage["planned_start"] == null) {
                                              DateTime? anchor;
                                              bool fromPrevEnd = false;

                                              for (int k = i - 1; k >= 0; k--) {
                                                final prev = _stages[k];
                                                if (prev["planned_end"] != null) {
                                                  anchor = prev["planned_end"];
                                                  fromPrevEnd = true;
                                                  break;
                                                }
                                                if (prev["planned_start"] != null && (prev["days"] ?? 0) > 0) {
                                                  anchor = prev["planned_start"];
                                                  fromPrevEnd = false;
                                                  break;
                                                }
                                              }

                                              if (anchor != null) {
                                                stage["planned_start"] = fromPrevEnd
                                                    ? anchor.add(const Duration(days: 1))
                                                    : anchor;
                                              }
                                            }

                                            // ⚠️ Nếu vẫn không có start thì mới cảnh báo
                                            if (stage["planned_start"] == null && days > 0) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text("⚠️ Vui lòng chọn ngày bắt đầu cho công đoạn trước khi nhập số ngày lớn hơn 0!"),
                                                ),
                                              );
                                              return;
                                            }

                                            // ✅ Tính ngày kết thúc
                                            DateTime? endDate;
                                            if (days == 0) {
                                              endDate = null;
                                            } else if (stage["planned_start"] != null) {
                                              endDate = stage["planned_start"].add(Duration(days: days - 1));
                                            }

                                            // 🚫 Kiểm tra phạm vi ngày
                                            if (_orderDate == null || _deliveryDate == null) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text("⚠️ Vui lòng chọn ngày đặt và ngày giao trước!")),
                                              );
                                              return;
                                            }

                                            if (endDate != null &&
                                                (endDate.isBefore(_orderDate!) || endDate.isAfter(_deliveryDate!))) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text("❌ Ngày công đoạn phải nằm trong khoảng ngày đặt - ngày giao!")),
                                              );
                                              return;
                                            }

                                            setState(() {
                                              stage["days"] = days;
                                              stage["planned_end"] = (days == 0) ? null : endDate;

                                              // 🔁 Tìm công đoạn trước gần nhất có planned_end hoặc planned_start
                                              DateTime? prevEnd;
                                              for (int j = i - 1; j >= 0; j--) {
                                                prevEnd = _stages[j]["planned_end"] ?? _stages[j]["planned_start"];
                                                if (prevEnd != null) break;
                                              }

                                              // ✅ Nếu công đoạn hiện tại bị bỏ qua, không gán planned_start
                                              if (days == 0) {
                                                stage["planned_start"] = null;
                                              }

                                              // ✅ Cập nhật công đoạn kế tiếp (và bỏ qua nhiều công đoạn 0 ngày liên tiếp)
                                              if (i + 1 < _stages.length) {
                                                DateTime? nextStart;

                                                if (days == 0) {
                                                  // Nếu công đoạn hiện tại = 0 → kế tiếp bắt đầu ngay sau prevEnd
                                                  if (prevEnd != null) {
                                                    nextStart = prevEnd.add(const Duration(days: 1));
                                                  }
                                                } else if (endDate != null) {
                                                  nextStart = endDate.add(const Duration(days: 1));
                                                }

                                                // Nếu tìm được ngày bắt đầu hợp lệ → gán cho công đoạn kế tiếp đầu tiên chưa có ngày
                                                if (nextStart != null) {
                                                  for (int k = i + 1; k < _stages.length; k++) {
                                                    if (_stages[k]["days"] == 0) continue; // bỏ qua công đoạn 0 ngày

                                                    // ✅ CẬP NHẬT NGÀY BẮT ĐẦU
                                                    _stages[k]["planned_start"] = nextStart;

                                                    // ✅ TỰ ĐỘNG TÍNH LẠI NGÀY KẾT THÚC (NẾU ĐÃ CÓ DAYS)
                                                    final nextDays = _stages[k]["days"] ?? 0;
                                                    if (nextDays > 0) {
                                                      _stages[k]["planned_end"] = nextStart.add(Duration(days: nextDays - 1));
                                                    }

                                                    break;
                                                  }
                                                }
                                              }
                                            });
                                          }
                                        });




                                        return TextFormField(
                                          controller: controller,
                                          focusNode: focusNode,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            labelText: "Số ngày",
                                            border: OutlineInputBorder(),
                                          ),
                                          onFieldSubmitted: (value) {
                                            final days = int.tryParse(value) ?? 0;
                                            if (stage["planned_start"] == null) return;

                                            DateTime endDate = stage["planned_start"];
                                            if (days > 0) endDate = stage["planned_start"].add(Duration(days: days - 1));

                                            setState(() {
                                              stage["days"] = days;
                                              stage["planned_end"] = days == 0 ? null : endDate;
                                              if (days > 0 && i + 1 < _stages.length) {
                                                _stages[i + 1]["planned_start"] = endDate.add(const Duration(days: 1));
                                              }
                                            });
                                          },

                                        );
                                      },
                                    ),
                                  ),

                                ],
                              ),

                              const SizedBox(height: 8),
                              // 🧾 Hiển thị ngày kết thúc
                              if (stage["planned_end"] != null)
                                Text(
                                  (stage["days"] == 0)
                                      ? "Công đoạn này được bỏ qua (0 ngày)"
                                      : (stage["planned_end"] != null
                                      ? "Kết thúc: ${DateFormat('dd/MM/yyyy').format(safeParseDate(stage["planned_end"])!)}"
                                      : "Chưa tính ngày kết thúc"),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: (stage["days"] == 0) ? Colors.grey : Colors.black,
                                  ),
                                ),

                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),

              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
                    : Text(isEdit ? "Cập nhật" : "Lưu"),
              ),

            ],
          ),
        ),
      ),
    );
  }
}
