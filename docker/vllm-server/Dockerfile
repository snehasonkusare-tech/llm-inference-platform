# Single stage — simpler and more reliable than multi-stage for this use case
FROM nvidia/cuda:12.4.0-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PIP_NO_CLEAN=1

RUN apt-get update && apt-get install -y \
    python3.11 python3.11-dev python3-pip \
    curl git && rm -rf /var/lib/apt/lists/*

# Use python3.11 explicitly for all pip installs
RUN python3.11 -m pip install --upgrade pip

# Install torch (CPU+CUDA compatible)
RUN python3.11 -m pip install --no-cache-dir \
    torch==2.3.0 \
    --extra-index-url https://download.pytorch.org/whl/cu124

# Install vLLM + all pinned deps in ONE command so pip resolves them together.
# Pinning rationale:
#   transformers 4.44+ removes LogitsWarper  → breaks lmformatenforcer
#   numpy 2.0+   removes numpy.lib.function_base → breaks outlines
#   outlines 0.0.34 is the version vLLM 0.4.3 was designed against
#   lm-format-enforcer 0.9.8 matches vLLM 0.4.3 requirements
RUN python3.11 -m pip install --no-cache-dir \
    vllm==0.4.3 \
    "transformers[torch]==4.41.2" \
    "numpy>=1.24,<2.0" \
    "outlines==0.0.34" \
    "lm-format-enforcer>=0.9.8,<0.11" \
    google-cloud-storage==2.16.0

COPY docker/vllm-server/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8000
ENTRYPOINT ["/entrypoint.sh"]
