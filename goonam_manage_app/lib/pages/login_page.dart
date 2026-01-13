import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/auth_service.dart';
import 'package:goonam_manage_app/pages/theme.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final nameCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final storage = const FlutterSecureStorage();
  bool _isLoading = false;

  Future<void> login() async {
    FocusScope.of(context).unfocus(); // ẩn bàn phím
    setState(() => _isLoading = true);

    try {
      await AuthService.login(nameCtrl.text.trim(), passCtrl.text.trim());

      // ✅ Không cần gọi PushHelper nữa — AuthService đã tự gửi device token.
      Navigator.pushReplacementNamed(context, '/orders');
    } catch (e) {
      print("❌ Login failed: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đăng nhập thất bại: ${e.toString()}',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Đăng nhập")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/logo_icon.png', width: 160),
                const SizedBox(height: 16),
                const Text(
                  "QUẢN LÝ ĐƠN HÀNG",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: GoonamTheme.secondary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: "Tên đăng nhập",
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Mật khẩu",
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  textInputAction: TextInputAction.done, // 🔹 hiện nút “Enter” là “Done”
                  onSubmitted: (_) => !_isLoading ? login() : null, // 🔹 nhấn Enter để đăng nhập
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : login,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Đăng nhập"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
