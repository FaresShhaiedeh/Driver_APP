import 'dart:async';
import 'dart:ui';
import 'package:driver_app/location_point.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:convert';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();
  const String notificationChannelId = 'my_foreground_service';

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: false,
      foregroundServiceNotificationId: 888,
      notificationChannelId: notificationChannelId,
      initialNotificationTitle: 'تطبيق السائق جاهز',
      initialNotificationContent: 'في انتظار بدء عملية التتبع.',
    ),
    iosConfiguration: IosConfiguration(
      onForeground: onStart,
      autoStart: false,
    ),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  await Hive.initFlutter();
  if (!Hive.isAdapterRegistered(LocationPointAdapter().typeId)) {
    Hive.registerAdapter(LocationPointAdapter());
  }
  final locationBox = await Hive.openBox<LocationPoint>('location_queue');

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) => service.setAsForegroundService());
    service.on('setAsBackground').listen((event) => service.setAsBackgroundService());
  }

  StreamSubscription<Position>? positionStream;
  String? serverUrl;
  String? authToken;

  Future<void> processQueue() async {
    if (locationBox.isEmpty) return;
    final keys = locationBox.keys.toList();
    for (final key in keys) {
  final locationPoint = locationBox.get(key);
  debugPrint('🚀 Sending POST to $serverUrl with token $authToken');

      if (locationPoint == null) continue;
      try {
        final response = await http.post(
          Uri.parse(serverUrl!),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Token $authToken'},
          body: jsonEncode(locationPoint.toMap()),
        );
        if (response.statusCode >= 200 && response.statusCode < 300) {
          await locationBox.delete(key);
        } else {
          break;
        }
      } catch (e) {
        break;
      }
    }
  }

  service.on('startTracking').listen((event) async {
    if (event == null) return;

    // --- الخطوة 2: استقبال المتغيرات مباشرة ---
    final busId = event['bus_id'];
    final apiBaseUrl = event['api_base_url'];
    authToken = event['auth_token'];
    // --- نهاية الخطوة 2 ---

    if (authToken == null || apiBaseUrl == null) {
      // هذا الشرط لا يجب أن يتحقق الآن، ولكنه يبقى كإجراء احترازي
      return;
    }

    serverUrl = '$apiBaseUrl/buses/$busId/update-location/';

    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'تتبع مباشر فعال',
        content: 'الحافلة #$busId قيد التتبع حالياً.',
      );
    }

    const locationSettings = LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);

    positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) async {
        final locationPoint = LocationPoint()
          ..latitude = position.latitude.toString()
          ..longitude = position.longitude.toString()
          ..speed = position.speed.toString();
        debugPrint('🚀 Sending POST to $serverUrl with token $authToken');

        try {
          final response = await http.post(
            Uri.parse(serverUrl!), // الآن serverUrl لن يكون null
            headers: {'Content-Type': 'application/json', 'Authorization': 'Token $authToken'},
            body: jsonEncode(locationPoint.toMap()),
          );
          if (response.statusCode >= 200 && response.statusCode < 300) {
            await processQueue();
          } else {
            await locationBox.add(locationPoint);
          }
        } catch (e) {
          await locationBox.add(locationPoint);
        }
      },
      onError: (error) {},
    );
  });

  service.on('stopService').listen((event) {
    positionStream?.cancel();
    service.stopSelf();
  });
}