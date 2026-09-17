"""Health and readiness endpoints."""

from datetime import UTC, datetime

from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app import __version__
from app.core.config import settings
from app.db.session import get_db
from app.schemas.health import HealthResponse, ReadinessResponse

router = APIRouter(tags=["health"])


@router.get("/health", response_model=HealthResponse, summary="Liveness check")
def health() -> HealthResponse:
    """Return process liveness. Does not touch the database."""
    return HealthResponse(
        service=settings.app_name,
        version=__version__,
        environment=settings.environment,
        timestamp=datetime.now(UTC),
    )


@router.get("/health/db", response_model=ReadinessResponse, summary="Database readiness check")
def health_db(db: Session = Depends(get_db)) -> ReadinessResponse:
    """Verify the database answers and report the PostGIS version."""
    try:
        db.execute(text("SELECT 1"))
    except SQLAlchemyError as exc:
        return ReadinessResponse(
            status="error",
            database="unreachable",
            detail=type(exc).__name__,
        )

    postgis_version: str | None = None
    try:
        postgis_version = db.execute(text("SELECT PostGIS_Version()")).scalar_one()
    except SQLAlchemyError:
        # The database is up but PostGIS is not installed in it.
        db.rollback()

    return ReadinessResponse(status="ok", database="reachable", postgis=postgis_version)
