"""Schemas for the health endpoint."""

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class HealthResponse(BaseModel):
    """Liveness payload returned by `GET /health`."""

    status: Literal["ok"] = "ok"
    service: str = Field(..., description="Name of the running service.")
    version: str = Field(..., description="Backend package version.")
    environment: str = Field(..., description="Deployment environment.")
    timestamp: datetime = Field(..., description="Server time, always UTC.")


class ReadinessResponse(BaseModel):
    """Readiness payload returned by `GET /health/db`."""

    status: Literal["ok", "error"]
    database: Literal["reachable", "unreachable"]
    postgis: str | None = Field(
        default=None, description="PostGIS extension version, when available."
    )
    detail: str | None = Field(default=None, description="Error detail, when status is error.")
