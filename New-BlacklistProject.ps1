param(
    [string]$ProjectName = "blacklist-app",
    [string]$RootPath = (Get-Location).Path,
    [switch]$InitGit
)

$ProjectRoot = Join-Path $RootPath $ProjectName

function New-Dir {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Write-Utf8File {
    param(
        [string]$Path,
        [string]$Content
    )

    $dir = Split-Path -Parent $Path
    if ($dir) {
        New-Dir $dir
    }

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

Write-Host "Creating project in: $ProjectRoot" -ForegroundColor Cyan

# -------------------------------------------------------------------
# Directory structure
# -------------------------------------------------------------------
$dirs = @(
    $ProjectRoot,
    (Join-Path $ProjectRoot "src"),
    (Join-Path $ProjectRoot "src/blacklist_app"),
    (Join-Path $ProjectRoot "src/blacklist_app/api"),
    (Join-Path $ProjectRoot "src/blacklist_app/api/routers"),
    (Join-Path $ProjectRoot "src/blacklist_app/auth"),
    (Join-Path $ProjectRoot "src/blacklist_app/db"),
    (Join-Path $ProjectRoot "src/blacklist_app/db/migrations"),
    (Join-Path $ProjectRoot "src/blacklist_app/services"),
    (Join-Path $ProjectRoot "src/blacklist_app/templates"),
    (Join-Path $ProjectRoot "src/blacklist_app/static"),
    (Join-Path $ProjectRoot "deploy"),
    (Join-Path $ProjectRoot "deploy/systemd"),
    (Join-Path $ProjectRoot "deploy/nginx"),
    (Join-Path $ProjectRoot "deploy/logrotate"),
    (Join-Path $ProjectRoot "tests")
)

foreach ($dir in $dirs) {
    New-Dir $dir
}

# -------------------------------------------------------------------
# Root files
# -------------------------------------------------------------------
Write-Utf8File -Path (Join-Path $ProjectRoot "README.md") -Content @'
# Blacklist App

Prototype web application for managing a blacklist with Check Point integration.

## Goals

- Human UI for operators
- Feed endpoint for gateways
- Secure ingest endpoint for management-side automation
- Audit logging
- SQLite in development, PostgreSQL later

## Development

### Create virtual environment

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -e .
```

### Run locally

```bash
uvicorn blacklist_app.main:app --reload
```

If your environment does not install the package in editable mode, you can also run with:

```bash
PYTHONPATH=src uvicorn blacklist_app.main:app --reload
```

## Structure

- `src/blacklist_app/` - application package
- `deploy/` - deployment templates
- `tests/` - tests
'@

Write-Utf8File -Path (Join-Path $ProjectRoot ".gitignore") -Content @'
# Python
__pycache__/
*.py[cod]
*.pyo
*.pyd
*.so
*.egg-info/
.pytest_cache/
.mypy_cache/
.ruff_cache/

# Virtual env
.venv/
venv/

# IDE/editor
.vscode/
.idea/

# OS
.DS_Store
Thumbs.db

# Env
.env

# Logs
*.log

# SQLite
*.db
*.sqlite3
'@

Write-Utf8File -Path (Join-Path $ProjectRoot ".env.example") -Content @'
APP_NAME=Blacklist Service
APP_ENV=development
APP_HOST=127.0.0.1
APP_PORT=8000
LOG_LEVEL=INFO

DATABASE_URL=sqlite:///./blacklist.db

EXPECTED_API_KEY=CHANGE_ME

LDAP_SERVER=ldaps://dc.example.local:636
LDAP_BASE_DN=DC=example,DC=local
LDAP_BIND_FORMAT={username}@example.local
LDAP_USE_TLS=true
'@

Write-Utf8File -Path (Join-Path $ProjectRoot "pyproject.toml") -Content @'
[build-system]
requires = ["setuptools>=68", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "blacklist-app"
version = "0.1.0"
description = "Check Point integrated blacklist service"
readme = "README.md"
requires-python = ">=3.10"
dependencies = [
    "fastapi[standard]>=0.115.0",
    "jinja2>=3.1.0",
    "sqlalchemy>=2.0.0",
    "alembic>=1.13.0",
    "pydantic>=2.0.0",
    "python-dotenv>=1.0.0",
    "ldap3>=2.9.1",
    "uvicorn>=0.30.0"
]

[tool.setuptools]
package-dir = {"" = "src"}

[tool.setuptools.packages.find]
where = ["src"]
'@

# -------------------------------------------------------------------
# Python package files
# -------------------------------------------------------------------
Write-Utf8File -Path (Join-Path $ProjectRoot "src/blacklist_app/__init__.py") -Content @'
__all__ = ["__version__"]
__version__ = "0.1.0"
'@

Write-Utf8File -Path (Join-Path $ProjectRoot "src/blacklist_app/main.py") -Content @'
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
'@

Write-Utf8File -Path (Join-Path $ProjectRoot "src/blacklist_app/settings.py") -Content @'
"""
Application settings.
"""

import os
from dataclasses import dataclass


@dataclass
class Settings:
    app_name: str = os.getenv("APP_NAME", "Blacklist Service")
    app_env: str = os.getenv("APP_ENV", "development")
    app_host: str = os.getenv("APP_HOST", "127.0.0.1")
    app_port: int = int(os.getenv("APP_PORT", "8000"))
    log_level: str = os.getenv("LOG_LEVEL", "INFO")
    database_url: str = os.getenv("DATABASE_URL", "sqlite:///./blacklist.db")
    expected_api_key: str = os.getenv("EXPECTED_API_KEY", "CHANGE_ME")


settings = Settings()
'@

Write-Utf8File -Path (Join-Path $ProjectRoot "src/blacklist_app/logging_config.py") -Content @'
"""
Logging configuration.
"""

import logging.config


def configure_logging() -> None:
    logging.config.dictConfig(
        {
            "version": 1,
            "disable_existing_loggers": False,
            "formatters": {
                "standard": {
                    "format": "%(asctime)s %(levelname)s %(name)s %(message)s"
                }
            },
            "handlers": {
                "console": {
                    "class": "logging.StreamHandler",
                    "formatter": "standard",
                }
            },
            "root": {
                "handlers": ["console"],
                "level": "INFO",
            },
        }
    )
'@

Write-Utf8File -Path (Join-Path $ProjectRoot "src/blacklist_app/api/__init__.py") -Content @'
'@

Write-Utf8File -Path (Join-Path $ProjectRoot "src/blacklist_app/api/routers/__init__.py") -Content @'
'@

Write-Utf8File -Path (Join-Path $ProjectRoot "src/blacklist_app/api/routers/ui.py") -Content @'
"""
Server-rendered UI routes.
"""

from fastapi import APIRouter, Request
from fastapi.templating import Jinja2Templates

router = APIRouter()
templates = Jinja2Templates(directory="src/blacklist_app/templates")


@router.get("/")
def home(request: Request):
    return templates.TemplateResponse(
        request=request,
        name="index.html",
        context={
            "title": "Blacklist Service (Mock UI)",
            "note": "UI is placeholder.",
        },
    )
'@

Write-Utf8File -Path (Join-Path $ProjectRoot "src/blacklist_app/api/routers/feeds.py") -Content @'
"""
Gateway feed endpoints.
"""

from fastapi import APIRouter, Response

router = APIRouter()


@router.get("/checkpoint.txt")
def checkpoint_flat_feed() -> Response:
    body = "# Blacklist feed (mock)\n"
    return Response(content=body, media_type="text/plain")
'@

Write-Utf8File -Path (Join-Path $ProjectRoot "src/blacklist_app/api/routers/entries.py") -Content @'
"""
CRUD API for blacklist entries.
"""

from fastapi import APIRouter

router = APIRouter()


@router.get("/entries")
def list_entries():
    return {
        "items": [],
        "count": 0,
        "note": "Entries endpoint is not implemented yet.",
    }
'@

Write-Utf8File -Path (Join-Path $ProjectRoot "src/blacklist_app/api/routers/ingest.py") -Content @'
"""
Management-side ingest endpoint.
"""

from fastapi import APIRouter, Header, HTTPException

from blacklist_app.settings import settings

router = APIRouter()


@router.post("/mgmt/ingest")
def mgmt_ingest(ip: str, x_api_key: str | None = Header(default=None)):
    if x_api_key != settings.expected_api_key:
        raise HTTPException(status_code=401, detail="Unauthorized")

    return {"status": "ok", "ip": ip}
'@

Write-Utf8File -Path (Join-Path $ProjectRoot "src/blacklist_app/auth/__init__.py") -Content @'
'@

Write-Utf8File -Path (Join-Path $ProjectRoot "src/blacklist_app/auth/ad_ldap.py") -Content @'
"""
Active Directory / LDAP helpers.
"""


def authenticate_against_ad(username: str, password: str) -> bool:
    # TODO:
    # - connect to LDAPS
    # - attempt bind using provided credentials
    # - fetch group membership if needed
    return False
'@

Write-Utf8File -Path (Join-Path $ProjectRoot "src/blacklist_app/auth/dependencies.py") -Content @'
"""
Authentication-related FastAPI dependencies.
"""


def get_current_user():
    # TODO: implement real auth
    return {"username": "demo-user"}
'@

Write-Utf8File -Path (Join-Path $ProjectRoot "src/blacklist_app/db/__init__.py") -Content @'
'@

Write-Utf8File -Path (Join-Path $ProjectRoot "src/blacklist_app/db/engine.py") -Content @'
"""
SQLAlchemy engine/session creation.
"""

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from blacklist_app.settings import settings

engine = create_engine(settings.database_url, future=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False, future=True)
'@

Write-Utf8File -Path (Join-Path $ProjectRoot "src/blacklist_app/db/models.py") -Content @'
"""
ORM models.
"""

from datetime import datetime

from sqlalchemy import DateTime, Integer, String
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    pass


class BlacklistEntry(Base):
    __tablename__ = "blacklist_entries"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    value: Mapped[str] = mapped_column(String(255), index=True)
    entry_type: Mapped[str] = mapped_column(String(50), default="ip")
    source: Mapped[str] = mapped_column(String(50), default="manual")
    reason: Mapped[str | None] = mapped_column(String(500), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class AuditEvent(Base):
    __tablename__ = "audit_events"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    actor: Mapped[str] = mapped_column(String(255))
    action: Mapped[str] = mapped_column(String(255))
    details: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
'@

Write-Utf8File -Path (Join-Path $ProjectRoot "src/blacklist_app/services/__init__.py") -Content @'
'@

Write-Utf8File -Path (Join-Path $ProjectRoot "src/blacklist_app/services/blacklist_service.py") -Content @'
"""
Business logic for blacklist handling.
"""


def list_active_entries() -> list[str]:
    # TODO: return active entries from DB
    return []
'@

Write-Utf8File -Path (Join-Path $ProjectRoot "src/blacklist_app/services/audit_service.py") -Content @'
"""
Audit logging helpers.
"""

import logging

logger = logging.getLogger("blacklist_app.audit")


def write_audit_event(actor: str, action: str, details: str | None = None) -> None:
    logger.info("actor=%s action=%s details=%s", actor, action, details)
'@

# -------------------------------------------------------------------
# Templates and static
# -------------------------------------------------------------------
Write-Utf8File -Path (Join-Path $ProjectRoot "src/blacklist_app/templates/base.html") -Content @'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <title>{% block title %}Blacklist Service{% endblock %}</title>
    <link href="{{ url_for('static', path='/styles.css') }}" rel="stylesheet" />
  </head>
  <body>
    <main class="container">
      {% block content %}{% endblock %}
    </main>
  </body>
</html>
'@

Write-Utf8File -Path (Join-Path $ProjectRoot "src/blacklist_app/templates/index.html") -Content @'
{% extends "base.html" %}

{% block title %}{{ title }}{% endblock %}

{% block content %}
<h1>{{ title }}</h1>
<p>{{ note }}</p>

<ul>
  <li><a href="/feeds/checkpoint.txt">Gateway feed (flat list)</a></li>
  <li><a href="/api/v1/entries">Entries API</a></li>
</ul>
{% endblock %}
'@

Write-Utf8File -Path (Join-Path $ProjectRoot "src/blacklist_app/templates/entries.html") -Content @'
{% extends "base.html" %}

{% block title %}Entries{% endblock %}

{% block content %}
<h1>Entries</h1>
<p>Placeholder page for future blacklist entry management.</p>
{% endblock %}
'@

Write-Utf8File -Path (Join-Path $ProjectRoot "src/blacklist_app/static/styles.css") -Content @'
body {
    font-family: Arial, sans-serif;
    margin: 0;
    padding: 0;
    background: #f4f4f4;
    color: #222;
}

.container {
    max-width: 960px;
    margin: 2rem auto;
    padding: 2rem;
    background: #fff;
    border-radius: 8px;
}

h1 {
    margin-top: 0;
}
'@

# -------------------------------------------------------------------
# Deploy files
# -------------------------------------------------------------------
Write-Utf8File -Path (Join-Path $ProjectRoot "deploy/systemd/blacklist-app.service") -Content @'
[Unit]
Description=Blacklist App (FastAPI/Uvicorn)
After=network.target

[Service]
Type=simple
User=blacklistapp
Group=blacklistapp
WorkingDirectory=/opt/blacklist-app
Environment=PYTHONUNBUFFERED=1
Environment=PYTHONPATH=/opt/blacklist-app/src
ExecStart=/opt/blacklist-app/.venv/bin/uvicorn blacklist_app.main:app --host 127.0.0.1 --port 8000
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
'@

Write-Utf8File -Path (Join-Path $ProjectRoot "deploy/nginx/blacklist-app.conf") -Content @'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Example for later:
    # location /api/v1/mgmt/ingest {
    #     ssl_verify_client on;
    #     proxy_pass http://127.0.0.1:8000;
    # }
}
'@

Write-Utf8File -Path (Join-Path $ProjectRoot "deploy/logrotate/blacklist-app") -Content @'
/var/log/blacklist-app/*.log {
    daily
    rotate 14
    compress
    missingok
    notifempty
    copytruncate
}
'@

# -------------------------------------------------------------------
# Tests
# -------------------------------------------------------------------
Write-Utf8File -Path (Join-Path $ProjectRoot "tests/test_smoke.py") -Content @'
def test_placeholder():
    assert True
'@

# -------------------------------------------------------------------
# Optional git init
# -------------------------------------------------------------------
if ($InitGit) {
    Write-Host "Initializing git repository..." -ForegroundColor Yellow
    Push-Location $ProjectRoot
    git init | Out-Null
    git branch -M main 2>$null
    Pop-Location
}

Write-Host ""
Write-Host "Done." -ForegroundColor Green
Write-Host "Project created at: $ProjectRoot" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. cd `"$ProjectRoot`""
Write-Host "2. python -m venv .venv"
Write-Host "3. .\.venv\Scripts\Activate.ps1"
Write-Host "4. pip install -e ."
Write-Host "5. uvicorn blacklist_app.main:app --reload"
Write-Host ""
Write-Host "If import resolution fails, run:" -ForegroundColor Cyan
Write-Host '$env:PYTHONPATH="src"'
Write-Host "uvicorn blacklist_app.main:app --reload"
