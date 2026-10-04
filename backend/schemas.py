from enum import Enum
from pydantic import BaseModel, ConfigDict, Field

class Condition(str, Enum):
    """Label kondisi cuaca yang dikirim ke client."""

    cerah = "Cerah"
    berawan = "Berawan"
    berpotensi_hujan = "Berpotensi Hujan"
    hujan = "Hujan"

class WeatherInput(BaseModel):
    """Body request untuk POST /api/v1/predict."""

    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    wind_speed: float = Field(
        ...,
        ge=0,
        le=300,
        description="Kecepatan angin dalam km/jam (0-300)",
    )
    humidity: float = Field(
        ...,
        ge=0,
        le=100,
        description="Kelembapan relatif dalam persen (0-100)",
    )

class WeatherPredictionResponse(BaseModel):
    """Body response sukses untuk POST /api/v1/predict."""

    wind_speed: float = Field(..., description="Echo kecepatan angin, km/jam")
    humidity: float = Field(..., description="Echo kelembapan, persen")
    condition: Condition = Field(..., description="Label kondisi cuaca")
    description: str = Field(..., description="Penjelasan singkat dalam bahasa Indonesia")

class HealthResponse(BaseModel):
    """Body response untuk endpoint /health."""

    status: str = Field(..., examples=["ok"])
    message: str = Field(..., examples=["WeatherPredict API is running"])