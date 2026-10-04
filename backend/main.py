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
    description=(
        "API untuk prediksi kondisi cuaca berdasarkan kecepatan angin dan "
        "kelembapan. Metode: rule-based, tanpa machine learning."
    ),
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


@app.get("/", include_in_schema=False)
def root() -> dict[str, str]:
    return {
        "service": "WeatherPredict API",
        "version": app.version,
        "docs": "/docs",
    }