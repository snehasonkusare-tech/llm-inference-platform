PROJECT_ID   = my-llm-platform
REGION       = us-central1
REGISTRY     = $(REGION)-docker.pkg.dev/$(PROJECT_ID)/llm-platform
TAG          ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo "latest")

.PHONY: auth build-vllm build-router build-all push-all deploy

auth:
	gcloud auth configure-docker $(REGION)-docker.pkg.dev

build-vllm:
	docker build \
		--platform linux/amd64 \
		-t $(REGISTRY)/vllm-server:$(TAG) \
		-t $(REGISTRY)/vllm-server:latest \
		-f docker/vllm-server/Dockerfile .

build-router:
	docker build \
		--platform linux/amd64 \
		-t $(REGISTRY)/inference-router:$(TAG) \
		-t $(REGISTRY)/inference-router:latest \
		-f docker/inference-router/Dockerfile .

build-all: build-vllm build-router

push-all:
	docker push $(REGISTRY)/vllm-server:$(TAG)
	docker push $(REGISTRY)/vllm-server:latest
	docker push $(REGISTRY)/inference-router:$(TAG)
	docker push $(REGISTRY)/inference-router:latest

deploy: auth build-all push-all
	@echo "Images pushed to $(REGISTRY)"
