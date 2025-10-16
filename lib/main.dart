import 'dart:io'; // 👈 ضروري لإضافة HttpOverrides
import 'package:driver_app/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// كلاس يسمح بتجاوز التحقق من شهادة SSL (للـ DevTunnels فقط)
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 👇 هذا السطر هو المفتاح — يخلي Flutter يتجاهل مشكلة SSL مؤقتًا
  // Only override certificates in debug builds to avoid disabling SSL validation in production
  if (kDebugMode) {
    HttpOverrides.global = MyHttpOverrides();
  }

  // شغّل التطبيق مباشرةً (SplashScreen بتعمل كل التهيئة)
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Driver App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const SplashScreen(),
    );
  }
}
