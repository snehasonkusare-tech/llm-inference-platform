FROM python:3.11-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    curl git && rm -rf /var/lib/apt/lists/*

RUN pip install --upgrade pip

# CPU-only torch (much smaller than CUDA build)
RUN pip install --no-cache-dir \
    torch==2.3.0 --extra-index-url https://download.pytorch.org/whl/cpu

# Inference + serving stack
RUN pip install --no-cache-dir \
    transformers==4.41.2 \
    accelerate==0.30.0 \
    fastapi==0.111.0 \
    uvicorn==0.30.0 \
    pydantic==2.7.1 \
    google-cloud-storage==2.16.0 \
    huggingface_hub==0.23.2 \
    sentencepiece==0.2.0 \
    protobuf==4.25.3

COPY docker/cpu-server/server.py /server.py
COPY docker/cpu-server/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8000
ENTRYPOINT ["/entrypoint.sh"]
