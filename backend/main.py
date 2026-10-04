from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

app = FastAPI(
    title="WeatherPredict API",
    description="API untuk prediksi kondisi cuaca berdasarkan kecepatan angin dan kelembapan",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Struktur data input
class WeatherInput(BaseModel):
    wind_speed: float = Field(..., ge=0, description="Kecepatan angin dalam km/jam")
    humidity: float = Field(..., ge=0, le=100, description="Kelembapan dalam persen")


# GET untuk mengecek API
@app.get("/health")
def health():
    return {
        "status": "ok",
        "message": "WeatherPredict API is running"
    }


# POST untuk prediksi cuaca
@app.post("/api/v1/predict")
def predict_weather(data: WeatherInput):

    wind = data.wind_speed
    humidity = data.humidity

    # Aturan prediksi
    if humidity < 60 and wind < 15:
        condition = "Cerah"
        description = "Kondisi cuaca cenderung cerah."

    elif humidity < 75:
        condition = "Berawan"
        description = "Kondisi cuaca cenderung berawan."

    elif humidity < 85 and wind >= 10:
        condition = "Berpotensi Hujan"
        description = "Kondisi cuaca berpotensi mengalami hujan."

    elif humidity >= 85 and wind >= 15:
        condition = "Hujan"
        description = "Kondisi cuaca diprediksi hujan."

    else:
        condition = "Berpotensi Hujan"
        description = "Kondisi cuaca berpotensi mengalami hujan."

    return {
        "wind_speed": wind,
        "humidity": humidity,
        "condition": condition,
        "description": description
    }