// في ملف: lib/splash_screen.dart

import 'package:driver_app/background_service.dart';
import 'package:driver_app/location_point.dart';
import 'package:driver_app/login_screen.dart';
import 'package:driver_app/map_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // نبدأ عمليات التهيئة الطويلة بعد عرض الواجهة
    _initializeAppAndNavigate();
  }

  Future<void> _initializeAppAndNavigate() async {
    // --- كل عمليات التهيئة التي كانت في main تم نقلها إلى هنا ---

    // 1. تهيئة Hive
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(LocationPointAdapter().typeId)) {
      Hive.registerAdapter(LocationPointAdapter());
    }
    await Hive.openBox<LocationPoint>('location_queue');

    // 2. تحميل ملف .env
    await dotenv.load(fileName: ".env");

    // 3. تهيئة الخدمة الخلفية
    await initializeService();

    // 4. قراءة البيانات المحفوظة لتحديد الشاشة التالية
    final prefs = await SharedPreferences.getInstance();
    final String? busId = prefs.getString('active_bus_id');
    final String? lineId = prefs.getString('active_line_id');

    // التأكد من أن الواجهة ما زالت موجودة قبل الانتقال
    if (!mounted) return;

    // 5. الانتقال إلى الشاشة المناسبة
    if (busId != null && lineId != null) {
      // إذا كان التتبع فعالاً، اذهب مباشرة إلى شاشة التتبع
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => MapScreen(busId: busId, lineId: lineId)),
      );
    } else {
      // وإلا، اذهب إلى شاشة تسجيل الدخول
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // هذه هي الواجهة التي تظهر فوراً عند تشغيل التطبيق
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('جاري التحميل...'),
          ],
        ),
      ),
    );
  }
}