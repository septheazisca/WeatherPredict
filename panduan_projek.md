## 1. Menjalankan Backend (FastAPI)

Buka terminal, lalu masuk ke folder backend:
```bash
cd /d "D:\....\WeatherPredict\backend" #(Contoh)
```

**2.1 Membuat Virtual Environment**
```bash
python -m venv venv
```

**2.2 Mengaktifkan Virtual Environment**
```bash
venv\Scripts\activate
```

Jika berhasil, terminal akan menampilkan `(venv)` di awal baris.

**2.3 Menginstal Dependensi**
```bash
pip install -r requirements.txt
```

**2.4 Menjalankan FastAPI**
```bash
uvicorn main:app --reload
```

| Layanan          | URL                        |
|------------------|----------------------------|
| Backend          | http://127.0.0.1:8000      |
| Swagger API Docs | http://127.0.0.1:8000/docs |



## 2. Menjalankan Frontend (Flutter)
Buka terminal baru, lalu masuk ke folder Flutter:

```bash
cd /d "D:\....\WeatherPredict\weather_predict" #(Contoh)
```

**3.1 Menginstal Dependensi**
```bash
flutter pub get
```

**3.2 Memeriksa Perangkat**
```bash
flutter devices
```

**3.3 Menjalankan Flutter di Chrome**
```bash
flutter run -d chrome #(Menjalankan di chrome)
```



## 3. Menjalankan Proyek
Pastikan dua terminal berjalan bersamaan. Backend harus aktif sebelum aplikasi Flutter digunakan.

**Terminal 1 (Backend)**
```bash
cd /d "D:\....\WeatherPredict\backend"
venv\Scripts\activate
uvicorn main:app --reload
```

**Terminal 2 (Flutter)**
```bash
cd /d "D:\....\WeatherPredict\weather_predict"
flutter run -d chrome
```

---

## 4. Alur Aplikasi
```text
Input Kecepatan Angin dan Kelembapan
                 |
                 v
              Flutter
                 |
                 v
          FastAPI Backend
                 |
                 v
           Prediksi Cuaca
                 |
                 v
     Hasil ditampilkan di Flutter
```

---

## 5. Endpoint API

| Method | Endpoint          | Deskripsi                 |
|--------|-------------------|---------------------------|
| GET    | `/health`         | Memeriksa status API      |
| POST   | `/api/v1/predict` | Memprediksi kondisi cuaca |

**Request**
```json
{
  "wind_speed": 15,
  "humidity": 80
}
```

**Response**
```json
{
  "wind_speed": 15,
  "humidity": 80,
  "condition": "Berpotensi Hujan",
  "description": "Kondisi cuaca berpotensi mengalami hujan."
}
```

---

## 7. Catatan

| Komponen         | Keterangan                    |
|------------------|-------------------------------|
| Backend          | FastAPI                       |
| Frontend         | Flutter                       |
| Metode prediksi  | Rule-based (aturan sederhana) |
| Machine Learning | Tidak digunakan               |
| Dataset          | Tidak digunakan               |

Backend harus dijalankan terlebih dahulu sebelum aplikasi Flutter digunakan.