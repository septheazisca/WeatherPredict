"""Definisi endpoint WeatherPredict API."""

from fastapi import APIRouter, status

from schemas import HealthResponse, WeatherInput, WeatherPredictionResponse
from services.predictor import classify

router = APIRouter()


@router.get(
    "/health",
    response_model=HealthResponse,
    tags=["ops"],
    summary="Periksa status API",
)
def health() -> HealthResponse:
    return HealthResponse(status="ok", message="WeatherPredict API is running")


@router.get(
    "/api/v1/health",
    response_model=HealthResponse,
    tags=["ops"],
    summary="Periksa status API (versi berprefiks)",
)
def health_v1() -> HealthResponse:
    return HealthResponse(status="ok", message="WeatherPredict API is running")


@router.post(
    "/api/v1/predict",
    response_model=WeatherPredictionResponse,
    status_code=status.HTTP_200_OK,
    tags=["prediction"],
    summary="Prediksi kondisi cuaca dari kecepatan angin dan kelembapan",
)
def predict_weather(data: WeatherInput) -> WeatherPredictionResponse:
    condition, description = classify(data.wind_speed, data.humidity)
    return WeatherPredictionResponse(
        wind_speed=data.wind_speed,
        humidity=data.humidity,
        condition=condition,
        description=description,
    )