from fastapi import FastAPI, HTTPException, Depends, Request
from fastapi.responses import StreamingResponse, Response
import httpx, os, time
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from auth import verify_api_key
from model_selector import select_backend
from rate_limiter import check_rate_limit

app = FastAPI(title="LLM Inference Router")

BACKENDS = {
    "llama3-8b":  os.getenv("LLAMA3_BACKEND",  "http://llama3-8b-svc.llm-serving:8000"),
    "mistral-7b": os.getenv("MISTRAL_BACKEND", "http://mistral-7b-svc.llm-serving:8000"),
    "gemma-2b":   os.getenv("GEMMA_BACKEND",   "http://gemma-2b-svc.llm-serving:8000"),
}

request_counter = Counter("router_requests_total", "Total requests", ["model", "status"])
latency_hist    = Histogram("router_latency_seconds", "Request latency", ["model"])

@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)

@app.get("/v1/models")
def list_models():
    return {
        "object": "list",
        "data": [{"id": m, "object": "model"} for m in BACKENDS.keys()]
    }

@app.post("/v1/chat/completions")
async def chat_completions(request: Request, api_key: str = Depends(verify_api_key)):
    body = await request.json()
    model = body.get("model", "llama3-8b")

    if model not in BACKENDS:
        raise HTTPException(status_code=400, detail=f"Unknown model: {model}. Available: {list(BACKENDS.keys())}")

    await check_rate_limit(api_key, model)

    backend_url = select_backend(model, BACKENDS)
    start = time.time()

    async def stream_response():
        async with httpx.AsyncClient(timeout=120.0) as client:
            async with client.stream(
                "POST",
                f"{backend_url}/v1/chat/completions",
                json=body,
                headers={"Content-Type": "application/json"}
            ) as resp:
                async for chunk in resp.aiter_bytes():
                    yield chunk
        latency_hist.labels(model=model).observe(time.time() - start)
        request_counter.labels(model=model, status="success").inc()

    return StreamingResponse(stream_response(), media_type="text/event-stream")
