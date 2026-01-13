import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:convert';

class TestLoginPage extends StatefulWidget {
  const TestLoginPage({super.key});

  @override
  State<TestLoginPage> createState() => _TestLoginPageState();
}

class _TestLoginPageState extends State<TestLoginPage> {
  String _log = "";
  bool _loading = false;

  void _addLog(String msg) {
    setState(() {
      _log += "${DateTime.now().toString().substring(11, 19)} - $msg\n";
    });
    print(msg);
  }

  Future<void> _testLogin() async {
    setState(() {
      _loading = true;
      _log = "";
    });

    try {
      _addLog("🚀 Bắt đầu test login...");

      final dio = Dio(BaseOptions(
        baseUrl: 'https://api.goonamvina.com/api',
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ));

      _addLog("📡 Đang gọi API login...");

      final response = await dio.post('/auth/login', data: {
        'name': 'admin',
        'password': 'Goonam@2003',
      });

      _addLog("✅ API trả về status: ${response.statusCode}");
      _addLog("📦 Response data type: ${response.data.runtimeType}");

      final data = response.data;
      _addLog("📋 Response: ${jsonEncode(data)}");

      if (data is Map<String, dynamic>) {
        _addLog("✅ Response là Map");

        final token = data['token'];
        _addLog("🔑 Token type: ${token.runtimeType}");
        _addLog("🔑 Token: ${token?.toString().substring(0, 20)}...");

        final user = data['user'];
        _addLog("👤 User type: ${user.runtimeType}");

        if (user is Map<String, dynamic>) {
          _addLog("✅ User là Map");
          _addLog("👤 User keys: ${user.keys.toList()}");

          final id = user['id'];
          _addLog("🆔 ID type: ${id.runtimeType}");
          _addLog("🆔 ID value: $id");

          final name = user['name'];
          _addLog("👤 Name type: ${name.runtimeType}");
          _addLog("👤 Name value: $name");

          final email = user['email'];
          _addLog("📧 Email type: ${email.runtimeType}");
          _addLog("📧 Email value: $email");

          final role = user['role'];
          _addLog("🎭 Role type: ${role.runtimeType}");
          _addLog("🎭 Role value: $role");

          // ✅ Test parse sang int
          try {
            int idInt;
            if (id is int) {
              idInt = id;
            } else if (id is String) {
              idInt = int.parse(id);
            } else {
              throw Exception("ID không phải int hoặc String: ${id.runtimeType}");
            }
            _addLog("✅ Parse ID thành int thành công: $idInt");
          } catch (e) {
            _addLog("❌ Lỗi parse ID: $e");
          }

        } else {
          _addLog("❌ User KHÔNG phải Map: ${user.runtimeType}");
        }

        _addLog("✅ TEST HOÀN TẤT - KHÔNG CÓ LỖI");

      } else {
        _addLog("❌ Response KHÔNG phải Map");
      }

    } catch (e, stackTrace) {
      _addLog("❌ LỖI: $e");
      _addLog("📍 Stack trace:");
      _addLog(stackTrace.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Test Login")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _loading ? null : _testLogin,
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text("Test Login API"),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                color: Colors.black87,
                child: SingleChildScrollView(
                  child: SelectableText(
                    _log.isEmpty ? "Chưa có log..." : _log,
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}