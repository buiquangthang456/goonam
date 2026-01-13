import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'package:dio/dio.dart';

class CreateUserPage extends StatefulWidget {
  const CreateUserPage({super.key});

  @override
  State<CreateUserPage> createState() => _CreateUserPageState();
}

class _CreateUserPageState extends State<CreateUserPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  String _selectedRole = 'staff'; // ✅ mặc định là nhân viên
  bool loading = false;

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => loading = true);

    try {
      final token = await AuthService.getToken();
      final dio = AuthService.dio;

      await dio.post(
        '/users',
        data: {
          'name': _nameCtrl.text,
          'email': _emailCtrl.text,
          'password': _passwordCtrl.text,
          'role': _selectedRole, // ✅ gửi role lên server
        },
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Tạo tài khoản thành công")),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Lỗi tạo tài khoản: $e")),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tạo người dùng mới")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: "Tên"),
                validator: (v) => v!.isEmpty ? "Nhập tên" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: "Email"),
                validator: (v) => v!.isEmpty ? "Nhập email" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordCtrl,
                decoration: const InputDecoration(labelText: "Mật khẩu"),
                obscureText: true,
                validator: (v) => v!.length < 6 ? "Ít nhất 6 ký tự" : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(labelText: "Chức vụ"),
                items: const [
                  DropdownMenuItem(value: 'director', child: Text('Giám đốc')),
                  DropdownMenuItem(value: 'manager', child: Text('Quản lý')),
                  DropdownMenuItem(value: 'staff', child: Text('Nhân viên')),
                ],
                onChanged: (value) {
                  setState(() => _selectedRole = value!);
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: loading ? null : _createUser,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: loading
                    ? const CircularProgressIndicator()
                    : const Text("Tạo tài khoản"),
              )
            ],
          ),
        ),
      ),
    );
  }
}
