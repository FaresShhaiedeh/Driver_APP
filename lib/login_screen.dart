import 'package:driver_app/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'map_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart'; // تأكد من وجود هذا الاستيراد

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _busIdController = TextEditingController();
  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Permission.location.request();
    await Permission.notification.request();
  }

  Future<bool> _handleGpsService() async {
    bool isGpsEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isGpsEnabled) {
      if (mounted) {
        await showDialog(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('خدمة الموقع غير مفعلة'),
            content: const Text('يرجى تفعيل خدمة تحديد المواقع (GPS) لبدء التتبع.'),
            actions: <Widget>[
              TextButton(
                child: const Text('إلغاء'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              TextButton(
                child: const Text('فتح الإعدادات'),
                onPressed: () {
                  Geolocator.openLocationSettings();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      }
      return false;
    }
    return true;
  }

  Future<void> _login() async {
    final bool isGpsReady = await _handleGpsService();
    if (!isGpsReady) {
      return;
    }

    if (_busIdController.text.isEmpty) {
      _showErrorDialog('خطأ في الإدخال', 'الرجاء إدخال رقم الحافلة.');
      return;
    }

    setState(() { _isLoading = true; });

    try {
      final busId = _busIdController.text;
      final busData = await _apiService.getBusData(busId);
      if (!mounted) return;
      final lineId = busData['bus_line']['route_id'];

      // --- هذا هو التعديل الرئيسي ---
      // حفظ البيانات في الذاكرة الدائمة عند نجاح تسجيل الدخول
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_bus_id', busId);
      await prefs.setString('active_line_id', lineId.toString());
      // --- نهاية التعديل ---

      final service = FlutterBackgroundService();
      final isRunning = await service.isRunning();
      if (!mounted) return;
      if (!isRunning) {
        service.startService();
      }

      // --- الخطوة 1: قراءة المتغيرات من dotenv وتمريرها ---
      final apiBaseUrl = dotenv.env['API_BASE_URL'];
      final authToken = dotenv.env['AUTH_TOKEN'];

      service.invoke('startTracking', {
        'bus_id': int.parse(busId),
        'line_id': lineId,
        'api_base_url': apiBaseUrl,
        'auth_token': authToken,
      });
      // --- نهاية الخطوة 1 ---

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => MapScreen(busId: busId, lineId: lineId)),
      );
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('فشل تسجيل الدخول', e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('موافق'),
              onPressed: () => Navigator.of(ctx).pop(),
            )
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل دخول السائق')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _busIdController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'أدخل رقم الحافلة',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: _login,
              child: const Text('بدء التتبع'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _busIdController.dispose();
    super.dispose();
  }
}
