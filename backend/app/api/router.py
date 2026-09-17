"""Aggregate API router.

Feature routers (stations, routes, predictions) get mounted here under
`settings.api_v1_prefix` as they are built.
"""

from fastapi import APIRouter

api_router = APIRouter(prefix="")
