"""Shared pytest fixtures.

These tests deliberately run without a live database: the suite must pass on a
fresh clone and in CI before Postgres is provisioned. Tests that need a real
database should request it explicitly once data models exist.
"""

import os

# Settings are cached at import time, so the environment must be set first.
os.environ.setdefault("ENVIRONMENT", "test")
os.environ.setdefault("DEBUG", "false")

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app.main import app  # noqa: E402


@pytest.fixture(scope="session")
def client() -> TestClient:
    """A TestClient bound to the FastAPI application."""
    with TestClient(app) as test_client:
        yield test_client
