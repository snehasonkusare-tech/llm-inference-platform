#!/bin/bash
set -euo pipefail

MODEL_NAME="${MODEL_NAME:?MODEL_NAME env var required}"
GCS_BUCKET="${GCS_BUCKET:-}"
WEIGHTS_DIR="/model-weights/${MODEL_NAME##*/}"
MAX_MODEL_LEN="${MAX_MODEL_LEN:-2048}"

echo "==> Starting CPU inference server for model: $MODEL_NAME"

if [[ -n "$GCS_BUCKET" ]]; then
  echo "==> Checking GCS cache: gs://${GCS_BUCKET}/models/${MODEL_NAME##*/}/"

  HAS_CACHE=$(python -c "
from google.cloud import storage
client = storage.Client()
blobs = list(client.list_blobs('${GCS_BUCKET}', prefix='models/${MODEL_NAME##*/}/config.json', max_results=1))
print('yes' if blobs else 'no')
")

  if [[ "$HAS_CACHE" == "yes" ]]; then
    echo "==> Cache hit — downloading from GCS"
    mkdir -p "$WEIGHTS_DIR"
    python -c "
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
    python -c "
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
    python -c "
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

echo "==> Launching CPU inference server"
export MODEL_PATH="$MODEL_PATH"
export MAX_MODEL_LEN="$MAX_MODEL_LEN"
exec uvicorn server:app \
  --host 0.0.0.0 \
  --port 8000 \
  --workers 1
