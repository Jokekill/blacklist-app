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