import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:goonam_manage_app/pages/create_user_page.dart';
import 'package:goonam_manage_app/pages/order_detail_page.dart';
import 'package:goonam_manage_app/pages/order_list_page.dart';
import 'package:goonam_manage_app/pages/login_page.dart';
import 'package:goonam_manage_app/services/auth_service.dart';
import 'package:goonam_manage_app/services/comment_polling_service.dart';
import 'package:goonam_manage_app/services/desktop_notification_service.dart';
import 'package:goonam_manage_app/services/realtime_service.dart';
import 'package:goonam_manage_app/services/windows_badge_helper.dart';
import 'package:path_provider/path_provider.dart';
import 'firebase_options.dart';
import 'package:month_year_picker/month_year_picker.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:goonam_manage_app/pages/theme.dart';
import 'package:goonam_manage_app/services/update_service.dart';
import 'package:goonam_manage_app/services/notification_helper.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';







/// 🔔 Local notifications instance
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();
String? _pendingLaunchArg;
/// 🔑 Global keys for navigation and snackbar access
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> messengerKey =
GlobalKey<ScaffoldMessengerState>();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('📩 Received background message: ${message.notification?.title}');
}

Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();

  // ⚙️ Đăng ký background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);


  if (Platform.isWindows) {

  }

  // ✅ Firebase init — chỉ trên nền tảng được hỗ trợ
  if (!Platform.isWindows) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // 📨 Đăng ký nhận topic 'all'
    final fcm = FirebaseMessaging.instance;
    await fcm.subscribeToTopic('all');

    // In ra token để debug nếu cần
    final token = await fcm.getToken();
    print("📱 FCM token: $token");
  }
  await NotificationHelper.init();


  // ✅ Cấu hình local notification (Android)
  const AndroidInitializationSettings initAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initSettings =
  InitializationSettings(android: initAndroid);
  await flutterLocalNotificationsPlugin.initialize(initSettings);


  // ✅ Lắng nghe thông báo FCM khi app đang mở

  // FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
  //   final notification = message.notification;
  //   if (notification != null) {
  //     // ✅ Hiển thị popup
  //     await NotificationHelper.show(notification.title, notification.body);
  //
  //     // ✅ Cập nhật badge qua helper (tự biết Windows hay mobile)
  //     await NotificationHelper.updateBadge(1);
  //   }
  // });

  FlutterError.onError = (details) {
    print("🔥 FlutterError: ${details.exception}");
    print(details.stack);
  };

  runApp(const MyApp());
  if (Platform.isWindows) {
    Future.delayed(const Duration(seconds: 2), () {
      if (_pendingLaunchArg != null) {
        final orderId = int.tryParse(_pendingLaunchArg!);
        if (orderId != null) {
          navigatorKey.currentState?.pushNamed(
            '/orders',
            arguments: {'orderId': orderId, 'initialTab': 'comments'},
          );
        }
        _pendingLaunchArg = null;
      }
    });
  }

}

class _AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      print('🧹 App đang thoát — dừng polling & cleanup');
      RealtimeService.disconnect();

    }
  }
}
/// 📦 Hàm xử lý điều hướng khi có message push
void handleMessageNavigation(RemoteMessage message, BuildContext context) {
  final data = message.data;
  final type = data['type'];
  final orderId = int.tryParse(data['order_id'] ?? '') ?? 0;
  final commentId =
  data['comment_id'] != null ? int.tryParse(data['comment_id']) : null;

  if (orderId == 0) return;

  if (type == 'order_created' ||
      type == 'stage_late' ||
      type == 'stage_done') {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            OrderDetailPage(orderId: orderId, initialTab: "timeline"),
      ),
    );
  } else if (type == 'comment_added') {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDetailPage(
          orderId: orderId,
          initialTab: "comments",
          commentId: commentId,
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: messengerKey,
      title: 'Goonam Manage',
      debugShowCheckedModeBanner: false,
      theme: GoonamTheme.theme,
      // 👇👇👇 THÊM PHẦN NÀY 👇👇👇
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        MonthYearPickerLocalizations.delegate, // <– CỰC KỲ QUAN TRỌNG
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('vi'),
      ],
      // 👆👆👆 THÊM PHẦN NÀY 👆👆👆
      home: const SplashPage(),
      routes: {
        '/login': (_) => LoginPage(),
        '/orders': (_) => const OrderListPage(),
        '/createUser': (_) => const CreateUserPage(),
        '/deepLink': (context) {
          final message =
          ModalRoute.of(context)!.settings.arguments as RemoteMessage;
          handleMessageNavigation(message, context);
          return const SizedBox.shrink();
        },
      },
    );
  }
}

/// 🕓 SplashPage — kiểm tra đăng nhập khi mở app
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    checkLogin();
  }

  Future<void> checkLogin() async {
    try {
      final token = await AuthService.getToken();
      final user = await AuthService.getStoredUser();

      if (!mounted) return;

      if (token != null && user != null) {
        Navigator.pushReplacementNamed(context, '/orders');

        // ✅ Khởi động polling sau khi login thành công
        if (Platform.isWindows) {
          Future.delayed(const Duration(seconds: 1), () async {
            // 👉 Khởi tạo taskbar badge sau khi app đã sẵn sàng
            // WindowsBadgeHelper.init();
            final user = await AuthService.getStoredUser();
            if (user != null) {
              await RealtimeService.init(user['id']);
            }
          });
        }

        // ✅ Kiểm tra cập nhật
        Future.delayed(const Duration(milliseconds: 500), () {
          UpdateService.checkForUpdate(navigatorKey.currentContext!);
        });
      } else {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      print("❌ Error in SplashPage checkLogin: $e");
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }

}