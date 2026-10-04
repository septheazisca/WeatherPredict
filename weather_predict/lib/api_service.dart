import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // static const String baseUrl = 'http://10.0.2.2:8000';
  // 10.0.2.2 digunakan Android Emulator untuk mengakses localhost komputer.

  static const String baseUrl = 'http://127.0.0.1:8000';
// 127.0.0.1 supaya kita bisa langsung mengetes di Chrome

  static Future<Map<String, dynamic>> predictWeather({
    required double windSpeed,
    required double humidity,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/predict'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'wind_speed': windSpeed,
        'humidity': humidity,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Gagal mendapatkan prediksi cuaca');
    }
  }
}