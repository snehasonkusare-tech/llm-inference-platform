import os
from fastapi import HTTPException

# In-memory rate limiting (use Redis in production)
_request_counts: dict = {}

RATE_LIMIT = int(os.getenv("RATE_LIMIT_PER_MINUTE", "100"))

async def check_rate_limit(api_key: str, model: str):
    import time
    now = int(time.time() / 60)  # current minute bucket
    key = f"{api_key}:{now}"

    _request_counts[key] = _request_counts.get(key, 0) + 1

    # Clean old keys
    old_key = f"{api_key}:{now - 1}"
    _request_counts.pop(old_key, None)

    if _request_counts[key] > RATE_LIMIT:
        raise HTTPException(
            status_code=429,
            detail=f"Rate limit exceeded: {RATE_LIMIT} requests/minute"
        )
