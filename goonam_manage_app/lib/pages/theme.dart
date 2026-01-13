import 'package:flutter/material.dart';

class GoonamTheme {
  // 🎯 Màu chủ đạo
  static const Color primary = Color(0xFFE60012); // Đỏ thương hiệu Goonam
  static const Color secondary = Color(0xFF4B4B4B); // Xám chữ
  static const Color background = Color(0xFFF8F9FB); // Nền sáng dịu, chuyên nghiệp
  static const Color accent = Color(0xFF0288D1); // Xanh nhấn nhẹ cho icon, link...

  static ThemeData theme = ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',

    // 🎨 Toàn cục
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.light(
      primary: primary,
      secondary: accent,
      surface: Colors.white,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
    ),

    // 🧱 AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: secondary,
      elevation: 1,
      shadowColor: Colors.black12,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 20,
        color: secondary,
      ),
      iconTheme: IconThemeData(color: secondary),
    ),

    // 🔲 Card Style
    cardTheme: const CardThemeData(
      color: Colors.white,
      elevation: 3,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),

    // 📝 Input Fields
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: Colors.black38),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
    ),

    // 🔘 Elevated Buttons
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    ),

    // 🔹 Text Buttons (ví dụ nút "Hủy" hoặc "Thoát")
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),

    // 🧾 Chip Style (Tag, trạng thái)
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      side: const BorderSide(color: Colors.transparent),
    ),

    // 📦 Floating Action Button (nút thêm đơn hàng)
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),

    // 🧭 Divider, PopupMenu
    dividerTheme: const DividerThemeData(
      color: Color(0xFFE0E0E0),
      thickness: 1,
    ),

    popupMenuTheme: const PopupMenuThemeData(
      color: Colors.white,
      elevation: 6,
      textStyle: TextStyle(color: secondary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
    ),
  );
}
