"""Verifikasi aturan prediksi terhadap test_skenario.md.

Jalankan dari folder backend:
    python verify_scenarios.py
"""

from services.predictor import classify

# (angin_km_jam, kelembapan_persen, label_yang_diharapkan)
CASES = [
    # Skenario utama 1-4
    (5, 45, "Cerah"),
    (8, 65, "Berawan"),
    (15, 80, "Berpotensi Hujan"),
    (25, 90, "Hujan"),
    # Skenario tambahan
    (0, 78, "Berpotensi Hujan"),
    (50, 84, "Berpotensi Hujan"),
    (5, 90, "Berpotensi Hujan"),
    (30, 70, "Berawan"),
    (25, 45, "Berawan"),
    (10, 30, "Cerah"),
]


def main() -> None:
    print("Verifikasi skenario:")
    all_ok = True
    for wind, humidity, expected in CASES:
        condition, _ = classify(wind, humidity)
        ok = condition.value == expected
        all_ok = all_ok and ok
        mark = "OK" if ok else f"GAGAL (harusnya {expected})"
        print(f"  angin={wind:>2} RH={humidity:>3} -> {condition.value:<18} {mark}")

    print()
    print("Semua sesuai." if all_ok else "Ada yang tidak sesuai.")


if __name__ == "__main__":
    main()