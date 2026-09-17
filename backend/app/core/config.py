"""Application configuration.

All settings are loaded from environment variables (or a local `.env` file,
which is never committed). See `.env.example` at the repository root for the
full list of supported variables.
"""

from functools import lru_cache
from typing import Literal

from pydantic import PostgresDsn, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Runtime settings for the Tandem backend."""

    model_config = SettingsConfigDict(
        env_file=(".env", "../.env"),
        env_file_encoding="utf-8",
        extra="ignore",
        case_sensitive=False,
    )

    # --- Application ---------------------------------------------------
    app_name: str = "Tandem API"
    environment: Literal["local", "test", "staging", "production"] = "local"
    debug: bool = True
    api_v1_prefix: str = "/api/v1"
    log_level: str = "INFO"

    # --- Server --------------------------------------------------------
    backend_host: str = "0.0.0.0"
    backend_port: int = 8000

    # --- CORS ----------------------------------------------------------
    # Comma-separated list in the environment, e.g. "http://localhost:3000".
    cors_origins: str = "http://localhost:3000"

    # --- Database ------------------------------------------------------
    postgres_user: str = "tandem"
    postgres_password: str = "tandem"
    postgres_host: str = "localhost"
    postgres_port: int = 5432
    postgres_db: str = "tandem"
    database_url: PostgresDsn | None = None

    # Bounds how long a new connection may block. Without this, libpq waits
    # indefinitely when nothing is listening and readiness checks hang.
    db_connect_timeout: int = 5
    db_pool_size: int = 5
    db_max_overflow: int = 10

    # --- Timezone ------------------------------------------------------
    # Tandem stores and computes every timestamp in UTC. This is documented
    # here so it is impossible to miss; do not change it.
    timezone: Literal["UTC"] = "UTC"

    @field_validator("database_url", mode="before")
    @classmethod
    def _empty_string_to_none(cls, v: str | None) -> str | None:
        return v or None

    @property
    def cors_origin_list(self) -> list[str]:
        """CORS origins parsed into a list."""
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]

    @property
    def sqlalchemy_database_uri(self) -> str:
        """The SQLAlchemy connection string.

        `DATABASE_URL` wins when it is set (this is what Docker Compose and CI
        provide); otherwise the URL is assembled from the discrete
        `POSTGRES_*` variables.
        """
        if self.database_url is not None:
            return str(self.database_url)
        return (
            f"postgresql+psycopg://{self.postgres_user}:{self.postgres_password}"
            f"@{self.postgres_host}:{self.postgres_port}/{self.postgres_db}"
        )


@lru_cache
def get_settings() -> Settings:
    """Return the cached settings singleton."""
    return Settings()


settings: Settings = get_settings()
