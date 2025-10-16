import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  // Allow overriding values for easier testing. If not provided, try reading from dotenv.
  final String? _overrideBaseUrl;
  final String? _overrideAuthToken;

  ApiService({String? baseUrl, String? authToken})
      : _overrideBaseUrl = baseUrl,
        _overrideAuthToken = authToken;

  String? get _baseUrl {
    if (_overrideBaseUrl != null) return _overrideBaseUrl;
    try {
      return dotenv.env['API_BASE_URL'];
    } catch (_) {
      return null;
    }
  }

  String? get _authToken {
    if (_overrideAuthToken != null) return _overrideAuthToken;
    try {
      return dotenv.env['AUTH_TOKEN'];
    } catch (_) {
      return null;
    }
  }

  // Accept an optional client for easier testing (defaults to new http.Client())
  Future<Map<String, dynamic>> getBusData(String busId, {http.Client? client}) async {
    if (_baseUrl == null || _authToken == null) {
      throw Exception('API configuration (URL or Token) is missing in .env file');
    }

    // Correct endpoint based on user-provided API documentation
    final url = Uri.parse('$_baseUrl/buses/$busId/');
    final headers = {'Authorization': 'Token $_authToken'};

    final usedClient = client ?? http.Client();
    try {
      final response = await usedClient.get(url, headers: headers);

      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        return jsonDecode(responseBody);
      } else {
  // Provide more details in the error log
  debugPrint('Error fetching bus data: ${response.body}');
        throw Exception('Failed to load bus data. Status code: ${response.statusCode}');
      }
    } finally {
      if (client == null) usedClient.close();
    }
  }

  Future<void> updateLocation(String busId, double latitude, double longitude, double speed, {http.Client? client}) async {
    if (_baseUrl == null || _authToken == null) {
      throw Exception('API configuration (URL or Token) is missing in .env file');
    }

    // Correct endpoint based on user-provided API documentation
    final url = Uri.parse('$_baseUrl/buses/$busId/update-location/');
    final headers = {
      'Authorization': 'Token $_authToken',
      'Content-Type': 'application/json',
    };
    final body = jsonEncode({
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'speed': speed.toString(),
    });

    final usedClient = client ?? http.Client();
    try {
      final response = await usedClient.post(url, headers: headers, body: body);

      // A successful POST might return 200 (OK) or 204 (No Content)
      if (response.statusCode != 200 && response.statusCode != 204) {
  // Provide more details in the error log
  debugPrint('Error updating location: ${response.body}');
        throw Exception('Failed to update location. Status code: ${response.statusCode}');
      }
    } finally {
      if (client == null) usedClient.close();
    }
  }
}
