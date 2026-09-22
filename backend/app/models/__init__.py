"""ORM models.

Import every model module here so that `Base.metadata` is fully populated for
Alembic autogenerate. Real domain models (stations, station status snapshots,
trips, weather observations, incidents) land here as the product is built.
"""

from app.db.base import Base

__all__ = ["Base"]
