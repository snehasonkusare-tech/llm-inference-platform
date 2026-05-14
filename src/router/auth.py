from fastapi import HTTPException, Security
from fastapi.security import APIKeyHeader
import os

API_KEY_HEADER = APIKeyHeader(name="Authorization", auto_error=False)

VALID_KEYS = set(os.getenv("VALID_API_KEYS", "sk-dev-key").split(","))

async def verify_api_key(authorization: str = Security(API_KEY_HEADER)):
    if not authorization:
        raise HTTPException(status_code=401, detail="Missing Authorization header")
    key = authorization.replace("Bearer ", "")
    if key not in VALID_KEYS:
        raise HTTPException(status_code=403, detail="Invalid API key")
    return key
