"""Tests for environment-driven configuration."""

from app.core.config import Settings


def test_database_uri_is_assembled_from_parts() -> None:
    settings = Settings(
        postgres_user="u",
        postgres_password="p",
        postgres_host="db",
        postgres_port=5432,
        postgres_db="tandem",
        database_url=None,
    )

    assert settings.sqlalchemy_database_uri == "postgresql+psycopg://u:p@db:5432/tandem"


def test_explicit_database_url_wins() -> None:
    settings = Settings(database_url="postgresql+psycopg://a:b@host:5432/other")

    assert settings.sqlalchemy_database_uri == "postgresql+psycopg://a:b@host:5432/other"


def test_cors_origins_are_parsed_into_a_list() -> None:
    settings = Settings(cors_origins="http://localhost:3000, http://127.0.0.1:3000")

    assert settings.cors_origin_list == ["http://localhost:3000", "http://127.0.0.1:3000"]


def test_internal_timezone_is_utc() -> None:
    assert Settings().timezone == "UTC"
