"""
Authentication-related FastAPI dependencies.
"""


def get_current_user():
    # TODO: implement real auth
    return {"username": "demo-user"}