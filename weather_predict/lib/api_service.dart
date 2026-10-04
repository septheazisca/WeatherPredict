import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models/weather.dart';

/// Error yang dilempar [ApiService] agar UI bisa membedakan penyebab
/// kegagalan (input tidak valid, server salah, atau tidak ada koneksi).
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Klien HTTP untuk WeatherPredict API.
class ApiService {
  /// Alamat backend.
  ///
  /// Dapat dioverride saat menjalankan aplikasi, tanpa perlu edit kode:
  /// ```bash
  /// flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000
  /// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
  /// ```
  ///
  /// Catatan: Android Emulator memakai `10.0.2.2` untuk mengakses
  /// localhost komputer, bukan `127.0.0.1`.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static const Duration _timeout = Duration(seconds: 10);

  /// Mengirim permintaan prediksi cuaca.
  ///
  /// Melempar [TimeoutException] bila server tidak merespons dalam 10 detik,
  /// dan [ApiException] bila server mengembalikan status selain 200.
  static Future<WeatherResult> predictWeather({
    required double windSpeed,
    required double humidity,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/v1/predict'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'wind_speed': windSpeed, 'humidity': humidity}),
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw ApiException('Format response tidak dikenali.');
      }
      return WeatherResult.fromJson(decoded);
    }

    if (response.statusCode == 422) {
      // Pydantic 422: {"detail": [{"loc": [...], "msg": "...", "type": "..."}]}
      var message = 'Input ditolak server.';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final detail = body['detail'];
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map && first['msg'] is String) {
            message = first['msg'] as String;
          }
        }
      } catch (_) {
        // Biarkan pesan default bila body error tidak bisa diparse.
      }
      throw ApiException(message, statusCode: 422);
    }

    throw ApiException(
      'Server error (${response.statusCode}).',
      statusCode: response.statusCode,
    );
  }

  /// Mengecek apakah backend hidup. Mengembalikan `true` bila siap menerima
  /// permintaan.
  static Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}