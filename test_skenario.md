# Test Skenario WeatherPredict

## Skenario Utama

| No | Angin (km/jam) | Kelembapan (%) |       Hasil        |
| -- |----------------|----------------|--------------------|
|  1 |        5       |       45       | Cerah              |
|  2 |        8       |       65       | Berawan            |
|  3 |       15       |       80       | Berpotensi Hujan   |
|  4 |       25       |       90       | Hujan              |
|  5 |        -       |       -        | Error: Input kosong |
|  6 |       -5       |       70       | Error: Angin < 0   |
|  7 |       10       |      120       | Error: RH > 100    |

## Skenario Tambahan

| No | Angin (km/jam) | Kelembapan (%) |      Hasil       | Keterangan                              |
| -- |----------------|----------------|------------------|-----------------------------------------|
|  8 |       10       |       30       | Cerah            | RH < 60 dan angin < 15                 |
|  9 |        0       |       78       | Berpotensi Hujan | RH 75–84, semua kecepatan angin         |
| 10 |       50       |       84       | Berpotensi Hujan | RH < 85 dan angin ≥ 10                  |
| 11 |        5       |       90       | Berpotensi Hujan | RH ≥ 85 tapi angin < 15 → cabang `else` |
| 12 |       30       |       70       | Berawan          | RH 60–74                                |
| 13 |       25       |       45       | Berawan          | RH < 60 tapi angin ≥ 15                 |
| 14 |        8       |       85       | Berpotensi Hujan | RH ≥ 85 tapi angin < 10                 |

## Catatan

Keempat label hasil prediksi: **Cerah**, **Berawan**, **Berpotensi Hujan**, **Hujan**.

Aturan yang berlaku (dipertahankan dari versi awal proyek):

| Label | Syarat |
|---|---|
| Cerah | RH < 60 **dan** angin < 15 km/jam |
| Berawan | RH < 75 (setelah syarat Cerah gagal terpenuhi) |
| Berpotensi Hujan | RH < 85 **dan** angin ≥ 10 km/jam |
| Hujan | RH ≥ 85 **dan** angin ≥ 15 km/jam |
| Berpotensi Hujan | Else: RH ≥ 85 dengan angin 10–14 km/jam |

Verifikasi otomatis:

```bash
cd backend
venv\Scripts\python.exe verify_scenarios.py
```