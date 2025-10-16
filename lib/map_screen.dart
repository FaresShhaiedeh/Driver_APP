import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MapScreen extends StatefulWidget {
  final String busId;
  final dynamic lineId;

  const MapScreen({
    super.key,
    required this.busId,
    required this.lineId,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  Timer? _timer;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _duration = Duration(seconds: _duration.inSeconds + 1);
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التتبع المباشر فعال'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(4.0),
          child: LinearProgressIndicator(
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
          ),
        ),
      ),
      // --- تعديل: استخدام ListView لحل مشكلة Overflow ---
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          const Icon(Icons.gps_fixed, size: 100, color: Colors.green),
          const SizedBox(height: 20),
          const Text(
            'التتبع المباشر فعال',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 40),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  InfoRow(label: 'رقم الحافلة:', value: widget.busId),
                  const Divider(),
                  InfoRow(label: 'رقم الخط:', value: widget.lineId.toString()),
                  const Divider(),
                  InfoRow(label: 'مدة الجلسة:', value: _formatDuration(_duration)),
                ],
              ),
            ),
          ),
          // --- تعديل: إضافة SizedBox لتوفير مسافة قبل الزر ---
          const SizedBox(height: 40),
          ElevatedButton.icon(
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('إيقاف التتبع'),
            // --- هذا هو الجزء الذي تم تعديله بالكامل لحل التحذير ---
            onPressed: () async {
              // 1. التقط كل ما تحتاجه من السياق قبل أي عملية await
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);

              // 2. قم بتنفيذ العمليات المتزامنة وغير المتزامنة
              final service = FlutterBackgroundService();
              service.invoke("stopService");

              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('active_bus_id');
              await prefs.remove('active_line_id');

              // 3. تحقق من أن الواجهة ما زالت موجودة
              if (!mounted) return;

              // 4. استخدم المتغيرات التي التقطتها بأمان
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('تم إيقاف التتبع.'),
                  backgroundColor: Colors.redAccent,
                ),
              );

              navigator.pushReplacement(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 15),
              textStyle: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const InfoRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}