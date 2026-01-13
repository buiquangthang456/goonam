import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:goonam_manage_app/main.dart';

class UpdateService {
  static const currentVersion = "1.0.20"; // ⚙️ Bản hiện tại của app
  static const versionApi = "https://api.goonamvina.com/api/app/version";

  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      print("🚀 Gọi API kiểm tra cập nhật: $versionApi");
      final res = await http.get(Uri.parse(versionApi));
      print("🌐 Response code: ${res.statusCode}");
      print("📦 Response body: ${res.body}");

      if (res.statusCode != 200) return;

      final data = jsonDecode(res.body);
      final latestVersion = data['version'];
      final changelog = data['changelog'];
      final downloadUrl = data['download_url'];

      if (latestVersion != currentVersion) {
        _showUpdateDialog(context, latestVersion, changelog, downloadUrl);
      }
    } catch (e) {
      debugPrint("❌ Lỗi kiểm tra cập nhật: $e");
    }
  }

  static void _showUpdateDialog(
      BuildContext context, String latest, String log, String url) {
    if (!context.mounted) return; // ✅ Kiểm tra context còn sống

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("🔔 Có bản cập nhật mới!"),
        content: Text(
          "Phiên bản hiện tại: $currentVersion\n"
              "Phiên bản mới: $latest\n\n"
              "Nội dung cập nhật:\n$log",
        ),
        actions: [
          ElevatedButton(
            child: const Text("Cập nhật ngay"),
            onPressed: () async {
              debugPrint("⚙️ Người dùng bấm 'Cập nhật ngay'");
              Navigator.pop(context);
              await _downloadAndInstall(url, context);
            },
          ),
          TextButton(
            child: const Text("Để sau"),
            onPressed: () {
              debugPrint("⏳ Người dùng chọn 'Để sau'");
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  static Future<void> _downloadAndInstall(String url, BuildContext context) async {
    try {
      final tempDir = Directory.systemTemp.path;
      final savePath = "$tempDir\\GoonamVinaSetup.exe";

      final dio = Dio();
      await dio.download(
        url,
        savePath,
        onReceiveProgress: (rec, total) {
          if (total != -1) {
            final percent = (rec / total * 100).toStringAsFixed(0);
            debugPrint("⬇️ Đang tải $percent%");
          }
        },
      );

      // ✅ Khi tải xong, chạy file cài đặt
      await Process.start(savePath, []);
      exit(0);
    } catch (e) {
      messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text("❌ Không thể tải hoặc cài đặt: $e")),
      );
    }
  }
}
