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