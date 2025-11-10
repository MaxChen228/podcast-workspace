"""Session factory helpers for SQLAlchemy."""

from __future__ import annotations

from contextlib import contextmanager
from typing import Iterator, Optional

from sqlalchemy import create_engine
from sqlalchemy.engine import Engine
from sqlalchemy.orm import Session, sessionmaker

_engine_cache: dict[str, Engine] = {}
_session_cache: dict[str, sessionmaker] = {}


def _get_or_create_engine(database_url: str) -> Engine:
    if database_url in _engine_cache:
        return _engine_cache[database_url]
    engine = create_engine(database_url, pool_pre_ping=True, future=True)
    _engine_cache[database_url] = engine
    return engine


def get_sessionmaker(database_url: Optional[str]) -> sessionmaker:
    """Return (and cache) a configured sessionmaker for the given database URL."""

    if not database_url:
        raise RuntimeError("DATABASE_URL is not configured")
    if database_url in _session_cache:
        return _session_cache[database_url]
    engine = _get_or_create_engine(database_url)
    maker = sessionmaker(bind=engine, autoflush=False, autocommit=False, expire_on_commit=False, future=True)
    _session_cache[database_url] = maker
    return maker


@contextmanager
def db_session(database_url: Optional[str]) -> Iterator[Session]:
    """Context manager that yields a SQLAlchemy session."""

    maker = get_sessionmaker(database_url)
    session = maker()
    try:
        yield session
        session.commit()
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()
