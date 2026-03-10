"""
Gateway feed endpoints.
"""

from fastapi import APIRouter, Response

router = APIRouter()


@router.get("/checkpoint.txt")
def checkpoint_flat_feed() -> Response:
    body = "# Blacklist feed (mock)\n"
    return Response(content=body, media_type="text/plain")