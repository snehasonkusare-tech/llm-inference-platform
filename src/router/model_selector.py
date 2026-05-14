import httpx

async def is_backend_healthy(url: str) -> bool:
    try:
        async with httpx.AsyncClient(timeout=2.0) as client:
            r = await client.get(f"{url}/health")
            return r.status_code == 200
    except Exception:
        return False

def select_backend(model: str, backends: dict) -> str:
    """Route to the correct backend based on model name."""
    if model not in backends:
        raise ValueError(f"Unknown model: {model}")
    return backends[model]
