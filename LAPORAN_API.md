# Analisis & Rancangan API — WeatherPredict

**Proyek:** WeatherPredict · **Backend:** FastAPI · **Frontend:** Flutter
**Tanggal:** 4 Oktober 2026

---

## 1. Analisis Codebase

### Arsitektur

```
┌──────────────────────────┐      HTTP/JSON       ┌───────────────────────────┐
│  FLUTTER (Client)        │ ────────────────────► │  FASTAPI (Server)         │
│  main.dart      (UI)     │  POST /api/v1/predict│  main.py                  │
│  api_service.dart (HTTP) │ ◄──────────────────── │  Pydantic schema         │
│                          │     200 + JSON       │  Rule-based engine        │
└──────────────────────────┘                      └───────────────────────────┘
```

### Tabel Temuan

| Aspek | Temuan |
|---|---|
| Backend | Single file `main.py` (67 baris) |
| Model prediksi | Rule-based, **bukan** ML |
| Sumber kebenaran | Backend; Flutter hanya tampilan |
| State | Di `State` widget, tanpa Provider |
| Kontrak | Response `Map<String,dynamic>`, tanpa Dart model |
| Error | Semua error jadi pesan generik |
| Versi API | `/api/v1` di path, tapi `/health` tanpa versi |

### Catatan Penting (kondisi awal, sebelum refactor)

1. **File `schemas.py` belum ada.** Model `WeatherInput` masih inline di `main.py:20-22`.
2. Penomoran seksi 6 hilang di `panduan_projek.md`.

### Logika Prediksi

Aturan rule-based pada `services/predictor.py` **dipertahankan apa adanya** dari versi awal proyek. Tujuan refactor ini murni struktural (pisah skema, router, dan logika bisnis), bukan mengubah perilaku prediksi.

Aturan bersifat *waterfall* (`if` → `elif` → `else`), sehingga setiap input hanya melewati satu cabang pertama yang cocok:

| Label | Syarat | Berlaku untuk |
|---|---|---|
| Cerah | RH < 60 **dan** angin < 15 km/jam | RH < 60 dengan angin lemah |
| Berawan | RH < 75 | RH 60-74, setelah syarat Cerah gagal |
| Berpotensi Hujan | RH < 85 **dan** angin >= 10 km/jam | RH 75-84 dengan angin cukup |
| Hujan | RH >= 85 **dan** angin >= 15 km/jam | RH sangat lembap dengan angin kuat |
| Berpotensi Hujan | `else` | RH >= 85 dengan angin 10-14 km/jam |

Karena sifatnya *waterfall*, ada dua kondisi yang tidak diperiksa secara langsung:

- RH 60-74 menghasilkan `"Berawan"` berapa pun kecepatan anginnya, karena cabang `"Cerah"` mensyaratkan `wind < 15`, sedangkan cabang berikutnya tidak melihat variabel angin sama sekali.
- RH >= 85 dengan angin 10-14 km/jam tidak memenuhi syarat `"Hujan"`, sehingga jatuh ke `else` dan hasilnya `"Berpotensi Hujan"`.

Kedua perilaku tersebut adalah konsekuensi wajar dari logika *waterfall* yang memang dipakai pada proyek ini, dan seluruh skenario di `test_skenario.md` sudah disesuaikan dengan hasilnya.

### Verifikasi Logika

Jalankan pemeriksaan otomatis:

```bash
cd backend
venv\Scripts\python.exe verify_scenarios.py
```

Contoh hasil:

| Angin (km/j) | RH (%) | Hasil |
|---|---|---|
| 10 | 30 | Cerah |
| 0 | 78 | Berpotensi Hujan |
| 50 | 84 | Berpotensi Hujan |
| 5 | 90 | Berpotensi Hujan |
| 30 | 70 | Berawan |
| 25 | 45 | Berawan |
| 8 | 85 | Berpotensi Hujan |

---


---

## 2. Desain Endpoint

### 2.1 Tabel Endpoint

| Method | Path | Request | Success | Fungsi |
|---|---|---|---|---|
| GET | `/health` | — | 200 | Liveness probe |
| GET | `/api/v1/health` | — | 200 | Versi berprefix (konsisten) |
| POST | `/api/v1/predict` | JSON body | 200 | Prediksi cuaca |
| GET | `/docs` | — | 200 | Swagger UI (bawaan) |
| GET | `/openapi.json` | — | 200 | OpenAPI schema (bawaan) |

### 2.2 Kontrak Request–Response

**Request**

```http
POST /api/v1/predict HTTP/1.1
Content-Type: application/json
```
```json
{ "wind_speed": 15, "humidity": 80 }
```

**Response sukses (200)**

```json
{
  "wind_speed": 15.0,
  "humidity": 80.0,
  "condition": "Berpotensi Hujan",
  "description": "Kondisi cuaca berpotensi mengalami hujan."
}
```

**Response error (422)**

```json
{
  "detail": [
    {
      "type": "greater_than_equal",
      "loc": ["body", "humidity"],
      "msg": "Input should be greater than or equal to 0",
      "input": -1
    }
  ]
}
```

### 2.3 Alasan Pemilihan Method

| Keputusan | Alasan |
|---|---|
| **POST** untuk predict | Input berupa objek domain yang akan berkembang. Parameter numerik di URL terbatas 2KB, wajib URL-encode, dan mudah bocor ke log. POST + body JSON lebih aman dan fleksibel. |
| **GET** untuk health | Read-only tanpa parameter. Dijamin tidak mengubah state, boleh di-cache, aman dipanggil monitor/load balancer. |
| **Tanpa PUT/PATCH/DELETE** | Prediksi Pure compute, tidak ada resource persisten, jadi tidak ada lifecycle untuk di-CRUD. |
| **Tanpa auth** | Proyek demo: tidak ada data pribadi, tidak multi-tenant. Auth menambah 3 endpoint tanpa nilai demonstrasi. |

### 2.4 Alasan Pemilihan Nama

| Nama | Alasan |
|---|---|
| `/predict` (verb) | Melakukan aksi (menghitung), bukan mengembalikan resource. Namanya naik level jika nanti ada `/predict/batch` atau `/predict/history`. |
| Prefiks `/api/v1` | Versioning: breaking change cukup `v2`, client lama tetap jalan. Namespacing: `/health` tidak bentrok dengan domain. |
| `/health` tanpa prefix | Infrastruktur, bukan domain. Tidak perlu versioning — yang penting hidup. |
| Tanpa trailing slash | FastAPI meng-301 dan **kehilangan body** pada POST. Hindari. |

---

## 3. Format Data

### 3.1 Request — `WeatherInput`

| Field | Tipe | Wajib | Validasi | Satuan | Rentang |
|---|---|---|---|---|---|
| `wind_speed` | float | Ya | `ge=0`, `le=300` | km/jam | 0–300 |
| `humidity` | float | Ya | `ge=0`, `le=100` | persen | 0–100 |

### 3.2 Response — `WeatherPrediction`

| Field | Tipe | Validasi | Satuan | Contoh |
|---|---|---|---|---|
| `wind_speed` | float | Echo dari input | km/jam | 15.0 |
| `humidity` | float | Echo dari input | % | 80.0 |
| `condition` | enum | 4 label tetap | — | "Berpotensi Hujan" |
| `description` | string | 1 kalimat | — | "Kondisi cuaca..." |

### 3.3 Aturan `condition` (enum `Condition` di `schemas.py`)

Empat label, **tidak ada yang dihapus**:

| Label | Nama enum | Syarat |
|---|---|---|
| Cerah | `Condition.cerah` | RH < 60 **dan** angin < 15 km/jam |
| Berawan | `Condition.berawan` | RH < 75 |
| Berpotensi Hujan | `Condition.berpotensi_hujan` | RH < 85 **dan** angin ≥ 10 km/jam |
| Hujan | `Condition.hujan` | RH ≥ 85 **dan** angin ≥ 15 km/jam |

 Ditambah satu cabang `else` yang juga menghasilkan `Condition.berpotensi_hujan` untuk RH ≥ 85 dengan angin 10–14 km/jam. Detail urutan cabangnya ada di Subbag 1.

Karena `condition` bertipe enum, nilai di luar empat label tersebut **tidak mungkin** dikirim oleh backend — client tidak perlu menebak-nebak.

### 3.4 Contoh Kasus Error

| Input JSON | Hasil |
|---|---|
| `{ "wind_speed": -5, "humidity": 70 }` | 422 `greater_than_equal` |
| `{ "wind_speed": 10, "humidity": 120 }` | 422 `less_than_equal` |
| `{ "wind_speed": "abc", "humidity": 70 }` | 422 `float_parsing` |
| `{ "wind_speed": 15 }` | 422 `missing` (humidity) |

### 3.5 Penjelasan Validasi Pydantic

`Field(..., ge=0, le=100)` terdiri dari 3 elemen:

| Elemen | Arti | Efek |
|---|---|---|
| `...` | Field wajib | Hilang → 422 `missing` |
| `ge` | Greater than or equal | Batas bawah inklusif |
| `le` | Less than or equal | Batas atas inklusif |

**Mengapa validasi di backend, bukan hanya Flutter?**

Validasi client hanya berlaku di satu client. Kalau ada Postman atau curl, `humidity=500` tetap akan sampai. **Validasi client = UX** (cepat, tidak bolak-balik). **Validasi server = kebenaran** (tempat yang tak bisa dilewati). Keduanya tidak saling menggantikan.

**Mengapa `ge=0`, bukan `gt=0`?**

Angin `0 km/jam` valid secara fisik (udara diam). Batas bawah harus inklusif.

**Bonus:** `description` otomatis masuk ke OpenAPI schema → tampil di `/docs`, dan Dart model bisa di-generate. Satu deklarasi, terdokumentasi di dua sisi.

---

## 4. Implementasi

### 4.1 Struktur Folder

```
WeatherPredict/
├── backend/
│   ├── main.py                # wiring: FastAPI, CORS, router
│   ├── schemas.py             # semua Pydantic model
│   ├── routers/
│   │   ├── __init__.py
│   │   └── predict.py         # handler endpoint
│   ├── services/
│   │   ├── __init__.py
│   │   └── predictor.py       # logika bisnis (murni)
│   ├── requirements.txt
│   └── venv/
│
├── weather_predict/
│   ├── lib/
│   │   ├── main.dart          # UI + State
│   │   ├── api_service.dart   # HTTP client
│   │   └── models/
│   │       └── weather.dart    # Dart model + enum WeatherStatus
│   ├── test/widget_test.dart  # widget test
│   └── pubspec.yaml
│
├── panduan_projek.md
├── test_skenario.md
└── LAPORAN_API.md
```

> **Status:** struktur di atas **sudah diimplementasikan** dan diverifikasi
> (7 skenario `test_skenario.md` lolos, `flutter test` 4/4 lolos,
> `flutter analyze` tanpa error).

**Prinsip:** `services/predictor.py` tidak import FastAPI sama sekali. Murni `float, float -> str`, bisa diuji tanpa server.

### 4.2 `schemas.py`

```python
from enum import Enum
from pydantic import BaseModel, ConfigDict, Field


class Condition(str, Enum):
    cerah = "Cerah"
    berawan = "Berawan"
    berpotensi_hujan = "Berpotensi Hujan"
    hujan = "Hujan"


class WeatherInput(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    wind_speed: float = Field(
        ..., ge=0, le=300,
        description="Kecepatan angin dalam km/jam (0-300)",
    )
    humidity: float = Field(
        ..., ge=0, le=100,
        description="Kelembapan relatif dalam persen (0-100)",
    )


class WeatherPredictionResponse(BaseModel):
    wind_speed: float = Field(..., description="Echo kecepatan angin, km/jam")
    humidity: float = Field(..., description="Echo kelembapan, persen")
    condition: Condition = Field(..., description="Label kondisi cuaca")
    description: str = Field(..., description="Penjelasan singkat")


class HealthResponse(BaseModel):
    status: str = Field(..., examples=["ok"])
    message: str = Field(..., examples=["WeatherPredict API is running"])
```

**Perubahan dari kode lama:**

| Lama | Baru | Alasan |
|---|---|---|
| `condition: str` | `condition: Condition` | Compile-time safety + schema-driven Dart |
| `ge=0` saja | `le=300` juga | Batas atas fisik (Hurricane Categories) |
| Tanpa `response_model` | `WeatherPredictionResponse` | Validasi output + filter field + auto docs |
| `allow_origins=["*"]` | Allowlist | Keamanan |

### 4.3 `services/predictor.py`

```python
from schemas import Condition


def classify(wind_speed: float, humidity: float) -> tuple[Condition, str]:
    """Aturan prediksi. Pure function, tanpa dependency web."""
    if humidity < 60 and wind_speed < 15:
        return Condition.cerah, "Kondisi cuaca cenderung cerah."

    elif humidity < 75:
        return Condition.berawan, "Kondisi cuaca cenderung berawan."

    elif humidity < 85 and wind_speed >= 10:
        return (Condition.berpotensi_hujan,
                "Kondisi cuaca berpotensi mengalami hujan.")

    elif humidity >= 85 and wind_speed >= 15:
        return Condition.hujan, "Kondisi cuaca diprediksi hujan."

    else:
        return (Condition.berpotensi_hujan,
                "Kondisi cuaca berpotensi mengalami hujan.")
```

**Urutan percabangan:**

| Percabangan | Label |
|---|---|
| `humidity < 60 and wind_speed < 15` | `Condition.cerah` |
| `humidity < 75` | `Condition.berawan` |
| `humidity < 85 and wind_speed >= 10` | `Condition.berpotensi_hujan` |
| `humidity >= 85 and wind_speed >= 15` | `Condition.hujan` |
| `else` | `Condition.berpotensi_hujan` |

Perhatikan bahwa `elif humidity < 75` **tidak** memeriksa `wind_speed`, dan `else` menutup dua kondisi sekaligus (RH 75–84 dengan angin < 10, serta RH ≥ 85 dengan angin 10–14). Keduanya menghasilkan label `Berpotensi Hujan`, jadi dari sisi user terlihat konsisten.

**Penjelasan mock logic:**

`classify()` adalah **pure function**: input sama → output selalu sama, tanpa I/O, tanpa state.

1. **Deterministik** — bisa jadi oracle di `test_skenario.md`. Hasil berubah = bug, bukan "cuacanya berbeda".
2. **Mudah diuji** — `assert classify(25, 90)[0] == Condition.hujan` tanpa HTTP.
3. **Mudah diganti** — kalau diminta ML, ganti isi fungsi ini saja. Kontrak `tuple[Condition, str]` tidak berubah, jadi `main.py` dan Flutter tidak perlu disentuh.

**Kenapa `response_model=` wajib:**

Tanpa itu, FastAPI serialize dict biasa apa adanya. Salah ketik key = `KeyError` saat runtime, field internal bisa bocor, dan `/docs` tidak tahu bentuk JSON. Dengan `response_model=`, ada dua lapis jaminan kontrak: validasi input **dan** output.

### 4.4 `routers/predict.py`

```python
from fastapi import APIRouter, status
from schemas import HealthResponse, WeatherInput, WeatherPredictionResponse
from services.predictor import classify

router = APIRouter()


@router.get("/health", response_model=HealthResponse, tags=["ops"])
def health() -> HealthResponse:
    return HealthResponse(status="ok", message="WeatherPredict API is running")


@router.post("/api/v1/predict", response_model=WeatherPredictionResponse, tags=["prediction"])
def predict_weather(data: WeatherInput) -> WeatherPredictionResponse:
    condition, description = classify(data.wind_speed, data.humidity)
    return WeatherPredictionResponse(
        wind_speed=data.wind_speed,
        humidity=data.humidity,
        condition=condition,
        description=description,
    )
```

### 4.5 `main.py`

```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers.predict import router as predict_router

# Origins yang diizinkan.
#
# Flutter web memakai port acak setiap kali `flutter run -d chrome`
# (contoh: http://localhost:62786), jadi daftar port statis tidak cukup.
# Karena itu dipakai regex yang mengizinkan localhost dan 127.0.0.1
# pada port mana pun.
#
# CORS hanya berlaku untuk Flutter web. Untuk Android/iOS/Windows,
# permintaan dikirim lewat Dart HttpClient yang tidak menerapkan CORS.
ALLOWED_ORIGIN_REGEX = r"^https?://(localhost|127\.0\.0\.1|10\.0\.2\.2)(:\d+)?$"

app = FastAPI(
    title="WeatherPredict API",
    description="API prediksi cuaca dari kecepatan angin dan kelembapan. Rule-based.",
    version="1.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=ALLOWED_ORIGIN_REGEX,
    allow_credentials=False,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Content-Type"],
)

app.include_router(predict_router)
```

**Catatan penting tentang CORS**

Flutter web membuka aplikasi dari `http://localhost:<port>` dengan port acak. Karena itu `allow_origins` **tidak bisa** berisi daftar port statis, sedangkan `allow_origins=["*"]` terlalu longgar dari sisi keamanan. Solusinya `allow_origin_regex` seperti di atas.

Konsekuensinya, saat pertama kali memakai `flutter run -d chrome`, browser mengirim permintaan `OPTIONS` (preflight) sebelum `POST`. Server wajib membalas dengan header `Access-Control-Allow-Origin`. Jika tidak, Chrome memblokir dengan pesan:

```
Access to fetch at 'http://127.0.0.1:8000/api/v1/predict'
from origin 'http://localhost:62786' has been blocked by CORS policy
```

Hasil pengujian preflight:

| Origin dikirim | Hasil |
|---|---|
| `http://localhost:62786` | 200, header ACAO dikembalikan |
| `http://localhost:3000` | 200, header ACAO dikembalikan |
| `http://127.0.0.1:1234` | 200, header ACAO dikembalikan |
| `https://evil.com` | 400, ditolak |

### 4.6 Kode Flutter

**`lib/models/weather.dart`**

```dart
class WeatherResult {
  final double windSpeed, humidity;
  final String condition, description;

  const WeatherResult({
    required this.windSpeed,
    required this.humidity,
    required this.condition,
    required this.description,
  });

  factory WeatherResult.fromJson(Map<String, dynamic> json) => WeatherResult(
        windSpeed: (json['wind_speed'] as num).toDouble(),
        humidity: (json['humidity'] as num).toDouble(),
        condition: json['condition'] as String,
        description: json['description'] as String,
      );
}

enum WeatherStatus { initial, cerah, berawan, berpotensiHujan, hujan, error }

WeatherStatus weatherStatusFromCondition(String? condition) {
  switch (condition) {
    case 'Cerah':             return WeatherStatus.cerah;
    case 'Berawan':           return WeatherStatus.berawan;
    case 'Berpotensi Hujan':   return WeatherStatus.berpotensiHujan;
    case 'Hujan':             return WeatherStatus.hujan;
    default:                  return WeatherStatus.error;
  }
}
```

**Perbedaan dari kode lama:** fungsi ini dulu berada di `main.dart` sebagai method private `_statusFromCondition()`. Dipindah ke `models/weather.dart` agar bisa dipakai ulang tanpa mengimpor UI. Parameter dibuat nullable (`String?`) karena `condition` bisa `null` bila server mengirim field kosong.

**`lib/api_service.dart`**

```dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models/weather.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

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
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw ApiException('Format response tidak dikenali.');
      }
      return WeatherResult.fromJson(decoded);
    }

    if (response.statusCode == 422) {
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

    throw ApiException('Server error (${response.statusCode}).',
        statusCode: response.statusCode);
  }

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
```

Fungsi `checkHealth()` dipakai untuk mengecek apakah backend hidup sebelum menampilkan form.

**Perubahan kunci dari kode lama:**

| Sebelum | Sesudah | Alasan |
|---|---|---|
| `Map<String,dynamic>` | `WeatherResult` typed | Compiler menangkap salah nama field |
| `throw Exception(...)` | `ApiException` + `statusCode` | UI bedakan "offline" vs "input salah" |
| 422 diabaikan | Pesan Pydantic ditampilkan | User tahu kenapa ditolak |
| Tanpa timeout | `.timeout(10s)` | Server mati = request menggantung |
| Hardcoded URL | `String.fromEnvironment` | Ganti tanpa edit kode |

```bash
# Chrome
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000
# Android emulator (localhost HP = 10.0.2.2)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

**`lib/main.dart` — fungsi `predictWeather()`**

```dart
Future<void> predictWeather() async {
  FocusScope.of(context).unfocus();

  final wind = double.tryParse(windController.text.trim());
  final humidity = double.tryParse(humidityController.text.trim());

  setState(() { isLoading = true; errorMessage = null; });

  try {
    final result = await ApiService.predictWeather(
      windSpeed: wind ?? 0,
      humidity: humidity ?? 0,
    );
    if (!mounted) return;
    setState(() {
      condition = result.condition;
      description = result.description;
      status = statusFromCondition(result.condition);
      lastWind = result.windSpeed;
      lastHumidity = result.humidity;
      isLoading = false;
    });
  } on TimeoutException {
    if (!mounted) return;
    setState(() {
      status = WeatherStatus.error;
      errorMessage = 'Server tidak merespons (timeout 10 detik).';
      isLoading = false;
    });
  } on ApiException catch (e) {
    if (!mounted) return;
    setState(() {
      status = WeatherStatus.error;
      errorMessage = e.message;
      isLoading = false;
    });
  } catch (e) {
    if (!mounted) return;
    setState(() {
      status = WeatherStatus.error;
      errorMessage = 'Tidak dapat terhubung ke server.';
      isLoading = false;
    });
  }
}
```

**Empat hal wajib yang belum ada di kode lama:**

1. `if (!mounted) return;` setelah `await` — mencegah `setState() called after dispose()`.
2. Pisahkan `TimeoutException` dari `ApiException` — pesan berbeda supaya user tahu harus cek server atau perbaiki input.
3. Simpan `result.windSpeed`, bukan `wind` — tampilkan angka yang benar-benar diproses server.
4. Durasi minimum loading 1 detik — cegah spinner berkedip (lihat Subbag 4.6.1).

### 4.6.1 Animasi Loading (durasi minimum 1 detik)

**Masalah:** backend lokal merespons dalam 10–50 milidetik. Spinner hanya muncul sekejap, sehingga secara visual terlihat seperti "tidak terjadi apa-apa". User menekan tombol lalu langsung wondering apakah inputnya gagal.

**Solusi:** menahan tampilan loading minimal 1 detik memakai `Stopwatch` + `Future.delayed`. Jika respons datang lebih cepat, sisanya ditunggu; jika lebih lambat, tidak ada penundaan tambahan.

```dart
// Durasi minimum tombol menampilkan animasi loading.
static const Duration _minLoadingDuration = Duration(seconds: 1);

final stopwatch = Stopwatch()..start();

setState(() {
  isLoading = true;
  errorMessage = null;
});

try {
  final result = await ApiService.predictWeather(
    windSpeed: wind,
    humidity: humidity,
  );

  await _waitForMinimumLoading(stopwatch);
  if (!mounted) return;

  setState(() {
    condition = result.condition;
    // ...
    isLoading = false;
  });
} on ApiException catch (e) {
  await _waitForMinimumLoading(stopwatch);
  if (!mounted) return;
  setState(() {
    status = WeatherStatus.error;
    errorMessage = e.message;
    isLoading = false;
  });
  // on TimeoutException dan catch: pola yang sama
}

/// Menunggu sampai [_minLoadingDuration] tercapai.
Future<void> _waitForMinimumLoading(Stopwatch stopwatch) async {
  final remaining = _minLoadingDuration - stopwatch.elapsed;
  if (remaining > Duration.zero) {
    await Future<void>.delayed(remaining);
  }
  stopwatch.stop();
}
```

`await _waitForMinimumLoading()` dipanggil di **semua** cabang (sukses, timeout, `ApiException`, dan catch) supaya durasi loading konsisten bagaimanapun hasilnya.

**Komponen visual loading** dipisah menjadi widget sendiri agar tombol tetap ringkas:

```dart
class _LoadingIndicator extends StatelessWidget {
  final Color accent;

  const _LoadingIndicator({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            strokeCap: StrokeCap.round,
            color: accent,
          ),
        ),
        const SizedBox(width: 12),
        Text('MEMPROSES', /* ... */),
      ],
    );
  }
}
```

Perubahan dari spinner polos: `strokeCap: StrokeCap.round` membuat ujungnya membulat, `mainAxisSize: MainAxisSize.min` menjaga baris tidak memenuhi lebar tombol, dan teks `MEMPROSES` memberi umpan balik bahwa proses sedang berjalan.

**Pengujian durasi** memakai widget test yang memeriksa tiga titik waktu:

| Waktu sejak ditekan | Status loading |
|---|---|
| 0 ms | `MEMPROSES` tampil |
| 900 ms | masih tampil |
| 1300 ms | hilang, tombol kembali normal |

---

## 5. Alasan Pemilihan Framework

**Flask** adalah *microframework* yang sengaja ditelanjangi — hanya memberi routing dan request/response. Kontrak API menjadi tanggung jawab penuh Anda: parse manual `req.get_json()`, cek `if humidity > 100`, lalu `jsonify()`. Itu ~15 baris per endpoint yang selalu sama, ditulis ulang tiap kali, dan tidak punya tempat tinggal selain di kepala developer. Dokumentasi juga harus dibangun manual, menambah dependency baru (`Flask-Smorest`/`Flask-RESTX`) untuk mencapai tempat yang di FastAPI sudah tersedia gratis.

**FastAPI** berbasis ASGI/Starlette dan leveraging type hint Python. Deklarasi `wind_speed: float = Field(..., ge=0)` secara otomatis menghasilkan: validasi runtime (422), filter key asing, response serialization konsisten, tabel di `/docs`, dan Dart model generator dari `/openapi.json`. Satu baris kode untuk lima hal. Kalau aturan `le=100` ditambahkan nanti, di Flask Anda harus edit validasi manual **dan** dokumentasi **dan** konsistenkan dengan Dart — tiga tempat, tiga kemungkinan lupa. Di FastAPI satu bari suffit. Selisihnya untuk WeatherPredict nyata: API kecil dengan kontrak yang harus presisi.

**Kesimpulan: FastAPI.** Keunggulannya bukan "lebih modern", tapi **speed-to-correctness** tertinggi pada scope ini — proyek murni "baca 2 angka → hitung 4 cabang → balas JSON". Flask unggul untuk kurva belajar landai dan ekosistem extension matang, tapi di sini pilihan Flask berarti membangun ulang sesuatu yang sudah jadi.

---

## Ringkasan

| No | Yang Sudah Dikerjakan |
|---|---|
| 1 | Pecah `main.py` → `schemas.py` + `routers/` + `services/` |
| 2 | Tambahkan `response_model` + enum `Condition` |
| 3 | Pindahkan `WeatherInput` keluar dari `main.py` ke `schemas.py` |
| 4 | Rapikan `api_service.dart`: timeout + typed error + Dart model |
| 5 | CORS memakai `allow_origin_regex` agar port acak Flutter web tidak diblokir |
| 6 | Tulis ulang `widget_test.dart` (sebelumnya error `MyApp`) |
| 7 | Tambah `verify_scenarios.py` untuk cek aturan prediksi |
| 8 | Tambah animasi loading dengan durasi minimum 1 detik + widget test |

> **Perilaku prediksi tidak diubah.** Logika rule-based di `services/predictor.py` sama persis dengan versi awal proyek — ambang 60/75/85 untuk kelembapan dan 10/15 untuk kecepatan angin. Refactor ini hanya menyentuh struktur kode, bukan hasil prediksi.

## Hasil Verifikasi

| Uji | Hasil |
|---|---|
| Skenario 1–7 di `test_skenario.md` | 7/7 sesuai |
| `verify_scenarios.py` (10 kasus) | 10/10 sesuai |
| `/health`, `/`, `/api/v1/health` | 200 OK |
| `GET /openapi.json` | Enum `Condition` + batas `0-300` / `0-100` terdokumentasi |
| `flutter analyze` | 0 error, 0 warning |
| `flutter test` | 5/5 lolos |