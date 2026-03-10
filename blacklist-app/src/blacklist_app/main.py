"""
Entry point for the web application.
"""

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

from blacklist_app.api.routers import entries, feeds, ingest, ui


def create_app() -> FastAPI:
    app = FastAPI(title="Blacklist Service", version="0.1.0")

    app.mount("/static", StaticFiles(directory="src/blacklist_app/static"), name="static")

    app.include_router(ui.router)
    app.include_router(feeds.router, prefix="/feeds", tags=["feeds"])
    app.include_router(ingest.router, prefix="/api/v1", tags=["ingest"])
    app.include_router(entries.router, prefix="/api/v1", tags=["entries"])

    return app


app = create_app()