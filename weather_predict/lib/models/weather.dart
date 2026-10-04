/// Model data hasil prediksi dari backend WeatherPredict API.
///
/// Field di sini harus sinkron dengan `WeatherPredictionResponse`
/// di backend/schemas.py.
library;

/// Label kondisi cuaca yang mungkin dikembalikan backend.
enum WeatherStatus {
  initial,
  cerah,
  berawan,
  berpotensiHujan,
  hujan,
  error,
}

/// Memetakan string `condition` dari API ke enum [WeatherStatus].
///
/// Mengembalikan [WeatherStatus.error] untuk label yang tidak dikenal,
/// sehingga kondisi baru di backend tidak diam-diam salah tampil.
WeatherStatus weatherStatusFromCondition(String? condition) {
  switch (condition) {
    case 'Cerah':
      return WeatherStatus.cerah;
    case 'Berawan':
      return WeatherStatus.berawan;
    case 'Berpotensi Hujan':
      return WeatherStatus.berpotensiHujan;
    case 'Hujan':
      return WeatherStatus.hujan;
    default:
      return WeatherStatus.error;
  }
}

/// Struktur respons `POST /api/v1/predict`.
class WeatherResult {
  final double windSpeed;
  final double humidity;
  final String condition;
  final String description;

  const WeatherResult({
    required this.windSpeed,
    required this.humidity,
    required this.condition,
    required this.description,
  });

  /// Membuat [WeatherResult] dari JSON hasil response API.
  ///
  /// Melempar [FormatException] bila bentuk JSON tidak sesuai kontrak.
  factory WeatherResult.fromJson(Map<String, dynamic> json) {
    return WeatherResult(
      windSpeed: (json['wind_speed'] as num).toDouble(),
      humidity: (json['humidity'] as num).toDouble(),
      condition: json['condition'] as String,
      description: json['description'] as String,
    );
  }
}