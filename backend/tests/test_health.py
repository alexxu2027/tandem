"""Tests for the health endpoints."""

from datetime import UTC, datetime

from fastapi.testclient import TestClient


def test_health_returns_ok(client: TestClient) -> None:
    response = client.get("/health")

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ok"
    assert body["service"]
    assert body["version"]


def test_health_timestamp_is_utc(client: TestClient) -> None:
    body = client.get("/health").json()

    timestamp = datetime.fromisoformat(body["timestamp"])
    assert timestamp.tzinfo is not None, "timestamps must be timezone-aware"
    assert timestamp.utcoffset() == UTC.utcoffset(None), "timestamps must be UTC"


def test_root_points_at_docs_and_health(client: TestClient) -> None:
    body = client.get("/").json()

    assert body["docs"] == "/docs"
    assert body["health"] == "/health"


def test_openapi_schema_is_served(client: TestClient) -> None:
    response = client.get("/openapi.json")

    assert response.status_code == 200
    assert "/health" in response.json()["paths"]
