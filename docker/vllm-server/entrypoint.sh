#!/bin/bash
set -euo pipefail

MODEL_NAME="${MODEL_NAME:?MODEL_NAME env var required}"
GCS_BUCKET="${GCS_BUCKET:-}"
WEIGHTS_DIR="/model-weights/${MODEL_NAME##*/}"
TENSOR_PARALLEL="${TENSOR_PARALLEL_SIZE:-1}"
MAX_MODEL_LEN="${MAX_MODEL_LEN:-8192}"

echo "==> Starting LLM inference server for model: $MODEL_NAME"

if [[ -n "$GCS_BUCKET" ]]; then
  echo "==> Checking GCS cache: gs://${GCS_BUCKET}/models/${MODEL_NAME##*/}/"

  HAS_CACHE=$(python3.11 -c "
from google.cloud import storage
client = storage.Client()
blobs = list(client.list_blobs('${GCS_BUCKET}', prefix='models/${MODEL_NAME##*/}/config.json', max_results=1))
print('yes' if blobs else 'no')
")

  if [[ "$HAS_CACHE" == "yes" ]]; then
    echo "==> Cache hit — downloading from GCS"
    mkdir -p "$WEIGHTS_DIR"
    python3.11 -c "
from google.cloud import storage
import os
client = storage.Client()
blobs = client.list_blobs('${GCS_BUCKET}', prefix='models/${MODEL_NAME##*/}/')
for blob in blobs:
    rel = blob.name[len('models/${MODEL_NAME##*/}/'):]
    if not rel:
        continue
    local = os.path.join('${WEIGHTS_DIR}', rel)
    os.makedirs(os.path.dirname(local), exist_ok=True)
    print(f'  {rel}')
    blob.download_to_filename(local)
print('Done.')
"
    MODEL_PATH="$WEIGHTS_DIR"
  else
    echo "==> Cache miss — downloading from HuggingFace"
    python3.11 -c "
from huggingface_hub import snapshot_download
import os
snapshot_download(
    repo_id='${MODEL_NAME}',
    local_dir='${WEIGHTS_DIR}',
    token=os.getenv('HF_TOKEN'),
    ignore_patterns=['*.msgpack', '*.h5', 'flax_model*']
)
"
    echo "==> Uploading to GCS for future pods"
    python3.11 -c "
from google.cloud import storage
import os
client = storage.Client()
bucket = client.bucket('${GCS_BUCKET}')
for root, dirs, files in os.walk('${WEIGHTS_DIR}'):
    for fname in files:
        local_path = os.path.join(root, fname)
        rel = os.path.relpath(local_path, '${WEIGHTS_DIR}')
        gcs_key = f'models/${MODEL_NAME##*/}/{rel}'
        print(f'  {rel}')
        bucket.blob(gcs_key).upload_from_filename(local_path)
print('Upload complete.')
"
    MODEL_PATH="$WEIGHTS_DIR"
  fi
else
  MODEL_PATH="$MODEL_NAME"
fi

echo "==> Launching vLLM server"

# Build vLLM args — omit GPU flags when running CPU-only
VLLM_ARGS=(
  --model "$MODEL_PATH"
  --host 0.0.0.0
  --port 8000
  --tensor-parallel-size "$TENSOR_PARALLEL"
  --max-model-len "$MAX_MODEL_LEN"
  --disable-log-requests
)

# Add GPU flags only when a GPU is present
if python3.11 -c "import torch; assert torch.cuda.is_available()" 2>/dev/null; then
  echo "==> GPU detected — enabling CUDA"
  VLLM_ARGS+=(--gpu-memory-utilization 0.90 --enable-chunked-prefill)
else
  echo "==> No GPU detected — running on CPU"
  VLLM_ARGS+=(--device cpu)
fi

exec python3.11 -m vllm.entrypoints.openai.api_server "${VLLM_ARGS[@]}"
