"""FastAPI application entrypoint.

Run locally with:
    uv run uvicorn app.main:app --reload
"""

import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app import __version__
from app.api.router import api_router
from app.api.routes import health
from app.core.config import settings

logging.basicConfig(level=settings.log_level.upper())

app = FastAPI(
    title=settings.app_name,
    version=__version__,
    description=(
        "Predictive Citi Bike navigation. All timestamps in this API are UTC "
        "and ISO 8601 formatted."
    ),
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Unversioned operational endpoints.
app.include_router(health.router)

# Versioned product API. Empty for now; feature routers mount onto api_router.
app.include_router(api_router, prefix=settings.api_v1_prefix)


@app.get("/", tags=["meta"], summary="Service banner")
def root() -> dict[str, str]:
    """Point callers at the docs and the health check."""
    return {
        "service": settings.app_name,
        "version": __version__,
        "docs": "/docs",
        "health": "/health",
    }
