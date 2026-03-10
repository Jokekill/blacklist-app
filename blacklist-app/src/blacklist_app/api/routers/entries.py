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