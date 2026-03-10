"""
Audit logging helpers.
"""

import logging

logger = logging.getLogger("blacklist_app.audit")


def write_audit_event(actor: str, action: str, details: str | None = None) -> None:
    logger.info("actor=%s action=%s details=%s", actor, action, details)