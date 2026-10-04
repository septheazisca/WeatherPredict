"""Logika bisnis prediksi cuaca.

Modul ini sengaja TIDAK meng-import FastAPI atau HTTP sama sekali,
sehingga bisa diuji tanpa menjalankan server.

CATATAN: aturan di bawah ini adalah logika rule-based dari versi awal
proyek dan dipertahankan apa adanya. Jangan ubah ambang kelembapan
(60/75/85) atau ambang kecepatan angin (10/15) tanpa alasan yang jelas.
"""

from schemas import Condition


def classify(wind_speed: float, humidity: float) -> tuple[Condition, str]:
    """Tentukan kondisi cuaca dari kecepatan angin dan kelembapan.

    Args:
        wind_speed: Kecepatan angin dalam km/jam (sudah tervalidasi 0-300).
        humidity: Kelembapan relatif dalam persen (sudah tervalidasi 0-100).

    Returns:
        Tuple (Condition, description).
    """
    if humidity < 60 and wind_speed < 15:
        return Condition.cerah, "Kondisi cuaca cenderung cerah."

    elif humidity < 75:
        return Condition.berawan, "Kondisi cuaca cenderung berawan."

    elif humidity < 85 and wind_speed >= 10:
        return (
            Condition.berpotensi_hujan,
            "Kondisi cuaca berpotensi mengalami hujan.",
        )

    elif humidity >= 85 and wind_speed >= 15:
        return Condition.hujan, "Kondisi cuaca diprediksi hujan."

    else:
        return (
            Condition.berpotensi_hujan,
            "Kondisi cuaca berpotensi mengalami hujan.",
        )