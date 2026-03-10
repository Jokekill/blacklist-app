"""
SQLAlchemy engine/session creation.
"""

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from blacklist_app.settings import settings

engine = create_engine(settings.database_url, future=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False, future=True)