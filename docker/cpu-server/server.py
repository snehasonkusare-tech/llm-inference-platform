"""
OpenAI-compatible CPU inference server using HuggingFace transformers.
Supports /v1/chat/completions, /v1/completions, /v1/models, /health.
"""

import os
import time
import uuid
import asyncio
from typing import List, Optional, Union

import torch
from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from transformers import AutoTokenizer, AutoModelForCausalLM, pipeline

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
MODEL_PATH = os.environ.get("MODEL_PATH", os.environ.get("MODEL_NAME", "google/gemma-2b-it"))
MAX_MODEL_LEN = int(os.environ.get("MAX_MODEL_LEN", "2048"))
MAX_NEW_TOKENS = int(os.environ.get("MAX_NEW_TOKENS", "512"))

app = FastAPI(title="CPU Inference Server")

# ---------------------------------------------------------------------------
# Load model at startup
# ---------------------------------------------------------------------------
tokenizer = None
model = None
pipe = None


@app.on_event("startup")
async def load_model():
    global tokenizer, model, pipe
    print(f"Loading model from {MODEL_PATH} ...")
    tokenizer = AutoTokenizer.from_pretrained(MODEL_PATH)
    model = AutoModelForCausalLM.from_pretrained(
        MODEL_PATH,
        torch_dtype=torch.float32,   # CPU needs float32
        device_map="cpu",
        low_cpu_mem_usage=True,
    )
    pipe = pipeline(
        "text-generation",
        model=model,
        tokenizer=tokenizer,
        device_map="cpu",
    )
    print("Model loaded.")


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------
class ChatMessage(BaseModel):
    role: str
    content: str


class ChatCompletionRequest(BaseModel):
    model: str
    messages: List[ChatMessage]
    max_tokens: Optional[int] = MAX_NEW_TOKENS
    temperature: Optional[float] = 0.7
    top_p: Optional[float] = 0.95
    stream: Optional[bool] = False


class CompletionRequest(BaseModel):
    model: str
    prompt: Union[str, List[str]]
    max_tokens: Optional[int] = MAX_NEW_TOKENS
    temperature: Optional[float] = 0.7
    top_p: Optional[float] = 0.95


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------
@app.get("/health")
async def health():
    if pipe is None:
        raise HTTPException(status_code=503, detail="Model not loaded yet")
    return {"status": "ok"}


@app.get("/v1/models")
async def list_models():
    return {
        "object": "list",
        "data": [{
            "id": MODEL_PATH,
            "object": "model",
            "created": int(time.time()),
            "owned_by": "local",
        }]
    }


@app.post("/v1/chat/completions")
async def chat_completions(req: ChatCompletionRequest):
    if pipe is None:
        raise HTTPException(status_code=503, detail="Model not loaded yet")

    # Build prompt using the tokenizer's chat template if available
    try:
        prompt = tokenizer.apply_chat_template(
            [m.dict() for m in req.messages],
            tokenize=False,
            add_generation_prompt=True,
        )
    except Exception:
        # Fallback: naive concatenation
        prompt = "\n".join(f"{m.role}: {m.content}" for m in req.messages)
        prompt += "\nassistant:"

    loop = asyncio.get_event_loop()
    result = await loop.run_in_executor(
        None,
        lambda: pipe(
            prompt,
            max_new_tokens=req.max_tokens or MAX_NEW_TOKENS,
            temperature=req.temperature,
            top_p=req.top_p,
            do_sample=req.temperature > 0,
            return_full_text=False,
        )
    )

    generated = result[0]["generated_text"]
    completion_id = f"chatcmpl-{uuid.uuid4().hex[:8]}"
    return {
        "id": completion_id,
        "object": "chat.completion",
        "created": int(time.time()),
        "model": req.model,
        "choices": [{
            "index": 0,
            "message": {"role": "assistant", "content": generated},
            "finish_reason": "stop",
        }],
        "usage": {
            "prompt_tokens": len(tokenizer.encode(prompt)),
            "completion_tokens": len(tokenizer.encode(generated)),
            "total_tokens": len(tokenizer.encode(prompt)) + len(tokenizer.encode(generated)),
        }
    }


@app.post("/v1/completions")
async def completions(req: CompletionRequest):
    if pipe is None:
        raise HTTPException(status_code=503, detail="Model not loaded yet")

    prompt = req.prompt if isinstance(req.prompt, str) else req.prompt[0]

    loop = asyncio.get_event_loop()
    result = await loop.run_in_executor(
        None,
        lambda: pipe(
            prompt,
            max_new_tokens=req.max_tokens or MAX_NEW_TOKENS,
            temperature=req.temperature,
            top_p=req.top_p,
            do_sample=req.temperature > 0,
            return_full_text=False,
        )
    )

    generated = result[0]["generated_text"]
    return {
        "id": f"cmpl-{uuid.uuid4().hex[:8]}",
        "object": "text_completion",
        "created": int(time.time()),
        "model": req.model,
        "choices": [{
            "text": generated,
            "index": 0,
            "finish_reason": "stop",
        }],
        "usage": {
            "prompt_tokens": len(tokenizer.encode(prompt)),
            "completion_tokens": len(tokenizer.encode(generated)),
            "total_tokens": len(tokenizer.encode(prompt)) + len(tokenizer.encode(generated)),
        }
    }
