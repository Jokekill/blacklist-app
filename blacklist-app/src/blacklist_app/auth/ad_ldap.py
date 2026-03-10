"""
Active Directory / LDAP helpers.
"""


def authenticate_against_ad(username: str, password: str) -> bool:
    # TODO:
    # - connect to LDAPS
    # - attempt bind using provided credentials
    # - fetch group membership if needed
    return False