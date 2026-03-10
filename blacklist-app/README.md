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